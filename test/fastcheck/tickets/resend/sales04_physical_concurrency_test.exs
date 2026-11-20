defmodule FastCheck.Tickets.Resend.Sales04PhysicalConcurrencyTest do
  use ExUnit.Case, async: false
  @moduletag :independent_db

  import Ecto.Query
  import FastCheck.TicketResendFixtures
  alias Ash.Changeset
  alias Ash.Query
  alias Ecto.Adapters.SQL.Sandbox
  alias FastCheck.Messaging.WhatsApp.{ConversationStateMachine, MessageCommand}
  alias FastCheck.Repo
  alias FastCheck.Sales.Conversation
  alias FastCheck.Tickets.Resend.{CanonicalEmailBackfill, Hash, Otp}

  setup do
    config = Repo.config()

    unless System.get_env("GITHUB_ACTIONS") == "true" and
             System.get_env("GITHUB_JOB") == "independent-db" and
             config[:hostname] == "127.0.0.1" and config[:port] == 5432 and
             config[:database] == "fastcheck_test" and config[:username] == "fastcheck_test" do
      raise "independent database tests require the disposable CI job"
    end

    :ok
  end

  test "physical competing snapshot choices retain exactly the winning ticket" do
    fixture = snapshot_fixture()
    [first, second] = fixture.codes
    expected = ticket_for(fixture, first)
    previous_request_fun = Application.get_env(:fastcheck, :whatsapp_request_fun)
    parent = self()

    Application.put_env(:fastcheck, :whatsapp_request_fun, fn _ ->
      send(parent, :unexpected_provider_call)
    end)

    on_exit(fn ->
      if previous_request_fun,
        do: Application.put_env(:fastcheck, :whatsapp_request_fun, previous_request_fun),
        else: Application.delete_env(:fastcheck, :whatsapp_request_fun)
    end)

    {winner, _loser} =
      hold_and_contend(fixture, fn -> inbound(fixture, first, "choice-a") end, fn ->
        inbound(fixture, second, "choice-b")
      end)

    assert {:ok, %{conversation: %{state: "verified_resend_delivery_queued"}}} = winner
    assert_state(fixture, "verified", expected, "consumed", 1)
    refute_receive :unexpected_provider_call, 0
  end

  test "physical duplicate snapshot choice keeps one binding and one intent" do
    fixture = snapshot_fixture()
    [first | _] = fixture.codes
    expected = ticket_for(fixture, first)

    {winner, _duplicate} =
      hold_and_contend(fixture, fn -> inbound(fixture, first, "duplicate") end, fn ->
        inbound(fixture, first, "duplicate")
      end)

    assert {:ok, %{conversation: %{state: "verified_resend_delivery_queued"}}} = winner
    assert_state(fixture, "verified", expected, "consumed", 1)
  end

  test "physical selection after exit cannot bind or enqueue" do
    fixture = snapshot_fixture()
    [first | _] = fixture.codes

    {exit_result, _selection} =
      hold_and_contend(fixture, fn -> inbound(fixture, "0", "exit-first") end, fn ->
        inbound(fixture, first, "choice-late")
      end)

    assert {:ok, %{conversation: %{state: "main_menu"}}} = exit_result
    assert_state(fixture, "expired", nil, "invalidated", 0)
  end

  test "physical exit after selection cannot rebind or create another intent" do
    fixture = snapshot_fixture()
    [first | _] = fixture.codes
    expected = ticket_for(fixture, first)

    {winner, _exit} =
      hold_and_contend(fixture, fn -> inbound(fixture, first, "choice-first") end, fn ->
        inbound(fixture, "0", "exit-late")
      end)

    assert {:ok, %{conversation: %{state: "verified_resend_delivery_queued"}}} = winner
    assert_state(fixture, "expired", expected, "invalidated", 1)
  end

  test "physical selection waiting on a lock observes authoritative expiry" do
    fixture = snapshot_fixture()
    [first | _] = fixture.codes

    {_, selection} =
      hold_and_contend(
        fixture,
        fn ->
          Repo.update_all(
            from(c in "sales_ticket_resend_challenges", where: c.id == ^fixture.challenge_id),
            set: [expires_at: DateTime.add(DateTime.utc_now(), -5, :second)]
          )
        end,
        fn -> inbound(fixture, first, "expired-choice") end
      )

    assert {:ok, %{conversation: %{state: "selecting_resend_ticket"}}} = selection
    assert_state(fixture, "expired", nil, "expired", 0)
  end

  test "new selection path rejects malformed foreign source and foreign challenge codes" do
    first = snapshot_fixture()
    other = snapshot_fixture()
    [valid | _] = first.codes
    [foreign | _] = other.codes

    for {text, wa} <- [
          {"1", first.wa},
          {"", first.wa},
          {nil, first.wa},
          {"FC-short", first.wa},
          {foreign, first.wa},
          {valid, other.wa}
        ] do
      unboxed(fn ->
        current = load_conversation(first.id)
        cmd = command(wa, text, "invalid-#{System.unique_integer([:positive])}")
        assert {:ok, response} = ConversationStateMachine.handle_inbound(cmd, current)
        assert response.conversation.state == "selecting_resend_ticket"
        actor = %{actor_type: :system, actor_id: "sales04-physical-test"}

        assert {:ok, _} =
                 response.conversation
                 |> Changeset.for_update(
                   :mark_reply_sent,
                   %{
                     provider_message_id: cmd.provider_message_id,
                     outbound_message_id: "out-invalid-#{System.unique_integer([:positive])}",
                     sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
                   },
                   actor: actor
                 )
                 |> Ash.update(authorize?: false)
      end)
    end

    assert_state(first, "verified", nil, "active", 0)
    assert_state(other, "verified", nil, "active", 0)
  end

  test "physical backfill CAS observes a concurrently committed email change" do
    fixture =
      unboxed(fn ->
        issued_ticket_candidate!(
          buyer_email: "before-#{System.unique_integer([:positive])}@example.com"
        )
      end)

    stale =
      unboxed(fn ->
        Repo.one!(
          from o in "sales_orders",
            where: o.id == ^fixture.order_id,
            select: %{id: o.id, email: o.buyer_email, canonical: o.buyer_email_canonical}
        )
      end)

    stale = %{stale | canonical: nil}

    unboxed(fn ->
      Repo.update_all(from(o in "sales_orders", where: o.id == ^fixture.order_id),
        set: [buyer_email_canonical: nil]
      )
    end)

    next_email = "after-#{fixture.order_id}@example.com"

    {_, result} =
      held_row(
        "sales_orders",
        fixture.order_id,
        fn ->
          Repo.update_all(from(o in "sales_orders", where: o.id == ^fixture.order_id),
            set: [buyer_email: next_email, buyer_email_canonical: next_email]
          )
        end,
        fn ->
          CanonicalEmailBackfill.reconcile_record(stale, %{updated: 0, invalid: 0, conflicts: 0})
        end
      )

    assert result == %{updated: 0, invalid: 0, conflicts: 1}

    assert unboxed(fn ->
             Repo.one!(
               from o in "sales_orders",
                 where: o.id == ^fixture.order_id,
                 select: {o.buyer_email, o.buyer_email_canonical}
             )
           end) == {next_email, next_email}
  end

  defp snapshot_fixture do
    unboxed(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      unique = System.unique_integer([:positive])
      wa = Integer.to_string(27_000_000_000 + unique)
      email = "snapshot-#{unique}@example.com"
      first = issued_ticket_candidate!(buyer_email: email, attendee_first_name: "First#{unique}")

      second =
        issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Second#{unique}")

      %{rows: [[id]]} =
        Repo.query!(
          "INSERT INTO sales_conversations (phone_e164, wa_id, preferred_language, state, state_data, needs_human, inserted_at, updated_at) VALUES ($1, $2, 'en', 'collecting_resend_otp', '{}', false, now(), now()) RETURNING id",
          ["+" <> wa, wa]
        )

      {:ok, challenge, otp} =
        Otp.issue(
          %{
            conversation_id: id,
            source_hash: Hash.source(%{conversation_id: id}),
            request_email_hash: Hash.email(email)
          },
          now,
          return_otp?: true
        )

      data = %{"resend_email" => email, "resend_challenge_public_id" => challenge.public_id}

      Repo.update_all(from(c in "sales_conversations", where: c.id == ^id),
        set: [state_data: data]
      )

      conversation = load_conversation(id)
      command = command(wa, otp, "verify-#{unique}")
      assert {:ok, result} = ConversationStateMachine.handle_inbound(command, conversation)
      assert result.conversation.state == "selecting_resend_ticket"
      codes = Regex.scan(~r/FC-[A-Za-z0-9_-]{22}/, result.response_body) |> List.flatten()
      assert length(codes) == 2
      actor = %{actor_type: :system, actor_id: "sales04-physical-test"}

      {:ok, sent} =
        result.conversation
        |> Changeset.for_update(
          :mark_reply_sent,
          %{
            provider_message_id: command.provider_message_id,
            outbound_message_id: "out-#{unique}",
            sent_at: now
          },
          actor: actor
        )
        |> Ash.update(authorize?: false)

      %{
        id: id,
        wa: wa,
        challenge_id: challenge.id,
        public_id: challenge.public_id,
        codes: codes,
        snapshot: sent.state_data["resend_snapshot"],
        conversation: sent,
        ticket_ids: [first.ticket_issue_id, second.ticket_issue_id]
      }
    end)
  end

  defp ticket_for(fixture, code) do
    digest =
      :crypto.hash(:sha256, "resend-choice:" <> fixture.public_id <> ":" <> code)
      |> Base.encode16(case: :lower)

    ticket = fixture.snapshot["choices"][digest]
    assert ticket in fixture.ticket_ids
    ticket
  end

  defp inbound(fixture, text, suffix),
    do:
      ConversationStateMachine.handle_inbound(
        command(fixture.wa, text, suffix),
        fixture.conversation
      )

  defp command(wa, text, suffix) do
    %MessageCommand{
      provider: "meta",
      provider_message_id: "wamid.physical.#{wa}.#{suffix}",
      phone_e164: "+" <> wa,
      wa_id: wa,
      message_type: "text",
      text_body: text,
      received_at: DateTime.utc_now() |> DateTime.truncate(:second),
      raw_payload_hash: "synthetic",
      correlation_id: "synthetic"
    }
  end

  defp load_conversation(id),
    do: Conversation |> Query.for_read(:get_by_id, %{id: id}) |> Ash.read_one!(authorize?: false)

  defp assert_state(fixture, status, ticket, snapshot_status, count) do
    unboxed(fn ->
      challenge =
        Repo.one!(
          from c in "sales_ticket_resend_challenges",
            where: c.id == ^fixture.challenge_id,
            select: map(c, [:status, :ticket_issue_id])
        )

      assert challenge == %{status: status, ticket_issue_id: ticket}

      assert load_conversation(fixture.id).state_data["resend_snapshot"]["status"] ==
               snapshot_status

      assert Repo.one!(
               from i in "sales_ticket_delivery_intents",
                 where: i.ticket_resend_challenge_id == ^fixture.challenge_id,
                 select: count(i.id)
             ) == count
    end)
  end

  defp hold_and_contend(fixture, action, contender) do
    held_row(
      "sales_conversations",
      fixture.id,
      fn ->
        Repo.query!("SELECT id FROM sales_ticket_resend_challenges WHERE id = $1 FOR UPDATE", [
          fixture.challenge_id
        ])

        action.()
      end,
      contender,
      fn ->
        Repo.query!("SELECT id FROM sales_ticket_resend_challenges WHERE id = $1 FOR UPDATE", [
          fixture.challenge_id
        ])
      end
    )
  end

  defp held_row(table, id, action, contender, extra_lock \\ fn -> :ok end)
       when table in ["sales_orders", "sales_conversations"] do
    parent = self()

    holder =
      Task.async(fn ->
        unboxed(fn ->
          Repo.transaction(fn ->
            %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
            Repo.query!("SELECT id FROM #{table} WHERE id = $1 FOR UPDATE", [id])
            extra_lock.()
            send(parent, {:holder, self(), pid})

            receive do
              :proceed -> action.()
            after
              10_000 -> raise "holder timed out"
            end
          end)
        end)
      end)

    assert_receive {:holder, holder_pid, holder_db}, 5_000

    task =
      Task.async(fn ->
        unboxed(fn ->
          %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
          send(parent, {:contender, self(), pid})

          receive do
            :start -> contender.()
          after
            5_000 -> raise "contender timed out"
          end
        end)
      end)

    assert_receive {:contender, contender_pid, contender_db}, 5_000
    assert holder_db != contender_db
    send(contender_pid, :start)
    await_blocked(contender_db, holder_db, System.monotonic_time(:millisecond) + 5_000)
    send(holder_pid, :proceed)
    assert {:ok, result} = Task.await(holder, 15_000)
    {result, Task.await(task, 15_000)}
  end

  defp await_blocked(contender, holder, deadline) do
    blockers = unboxed(fn -> Repo.query!("SELECT pg_blocking_pids($1)", [contender]).rows end)

    cond do
      blockers == [[[holder]]] ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        flunk("contender did not wait on the held transaction")

      true ->
        Process.sleep(10)
        await_blocked(contender, holder, deadline)
    end
  end

  defp unboxed(fun), do: Sandbox.unboxed_run(Repo, fun)
end
