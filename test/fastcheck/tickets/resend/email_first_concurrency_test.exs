defmodule FastCheck.Tickets.Resend.EmailFirstConcurrencyTest do
  use ExUnit.Case, async: false
  @moduletag :independent_db

  import Ecto.Query
  import FastCheck.TicketResendFixtures
  alias Ecto.Adapters.SQL.Sandbox
  alias FastCheck.Messaging.WhatsApp.MessageCommand
  alias FastCheck.Repo
  alias FastCheck.Tickets.Resend.{EmailOtp, Hash, Otp, RateLimit}

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

  test "independent connections serialize issuance by email and source" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    unique = System.unique_integer([:positive])
    scopes = for n <- 1..4, do: scope(now, unique * 100 + n)
    email = "race#{unique}@example.com"
    deliver = fn _ -> {:ok, %{}} end

    for context <- Enum.take(scopes, 2) do
      assert {:ok, %{public_status: :accepted}} =
               unboxed(fn ->
                 EmailOtp.request_email_first(email, context, deliver_fun: deliver)
               end)
    end

    results =
      contend(
        fn -> RateLimit.lock!(["email:" <> Hash.email(email)]) end,
        Enum.drop(scopes, 2),
        fn context ->
          EmailOtp.request_email_first(email, context, deliver_fun: deliver)
        end
      )

    assert Enum.count(results, &match?({:ok, %{public_status: :accepted}}, &1)) == 1

    assert unboxed(fn ->
             Repo.one!(
               from c in "sales_ticket_resend_challenges",
                 where: c.request_email_hash == ^Hash.email(email),
                 select: count(c.id)
             )
           end) == 3

    context = {id, _} = scope(now, unique * 100 + 90)

    for n <- 1..4 do
      assert {:ok, %{public_status: :accepted}} =
               unboxed(fn ->
                 EmailOtp.request_email_first("source#{unique}-#{n}@example.com", context,
                   deliver_fun: deliver
                 )
               end)
    end

    results =
      contend(
        fn -> RateLimit.lock!(["source:" <> Hash.source(%{conversation_id: id})]) end,
        5..6,
        fn n ->
          EmailOtp.request_email_first("source#{unique}-#{n}@example.com", context,
            deliver_fun: deliver
          )
        end
      )

    assert Enum.count(results, &match?({:ok, %{public_status: :accepted}}, &1)) == 1

    assert unboxed(fn ->
             Repo.one!(
               from c in "sales_ticket_resend_challenges",
                 where: c.source_hash == ^Hash.source(%{conversation_id: id}),
                 select: count(c.id)
             )
           end) == 5
  end

  test "independent connections serialize OTP verification and competing ticket binds" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    unique = System.unique_integer([:positive])
    {id, command} = scope(now, unique)
    email = "bind#{unique}@example.com"

    {challenge, otp, first, second} =
      unboxed(fn ->
        first = issued_ticket_candidate!(buyer_email: email)
        second = issued_ticket_candidate!(buyer_email: email)

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

        {challenge, otp, first, second}
      end)

    context = {id, command, email}

    verify =
      contend(fn -> lock_challenge(challenge.id) end, 1..2, fn _ ->
        Otp.verify(challenge.public_id, otp, now, context)
      end)

    assert Enum.count(verify, &match?({:ok, _}, &1)) == 1
    assert Enum.count(verify, &match?({:error, :already_verified}, &1)) == 1

    binds =
      contend(
        fn -> lock_challenge(challenge.id) end,
        [first.ticket_issue_id, second.ticket_issue_id],
        fn ticket -> Otp.bind(challenge.public_id, ticket, now, context) end
      )

    assert Enum.count(binds, &(&1 == {:ok, :bound})) == 1
    assert Enum.count(binds, &(&1 == {:error, :invalid_or_expired})) == 1

    row =
      unboxed(fn ->
        Repo.one!(
          from c in "sales_ticket_resend_challenges",
            where: c.id == ^challenge.id,
            select: map(c, [:ticket_issue_id, :request_name_hash, :status])
        )
      end)

    assert row.ticket_issue_id in [first.ticket_issue_id, second.ticket_issue_id]
    assert row.request_name_hash == nil
    assert row.status == "verified"
  end

  test "independent wrong attempts are all recorded" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    unique = System.unique_integer([:positive])
    {id, command} = scope(now, unique)
    email = "attempt#{unique}@example.com"
    {challenge, otp} = issue(id, email, now)
    wrong = if otp == "000000", do: "111111", else: "000000"

    results =
      contend(fn -> lock_challenge(challenge.id) end, 1..2, fn _ ->
        Otp.verify(challenge.public_id, wrong, now, {id, command, email})
      end)

    assert Enum.all?(results, &(&1 == {:error, :invalid_or_expired}))

    for _ <- 1..3,
        do:
          assert(
            {:error, :invalid_or_expired} =
              unboxed(fn -> Otp.verify(challenge.public_id, wrong, now, {id, command, email}) end)
          )

    row =
      unboxed(fn ->
        Repo.one!(
          from c in "sales_ticket_resend_challenges",
            where: c.id == ^challenge.id,
            select: map(c, [:status, :failed_attempt_count])
        )
      end)

    assert row == %{status: "blocked", failed_attempt_count: 5}
  end

  test "binding and invalidation serialize on the challenge row" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    unique = System.unique_integer([:positive])
    {id, command} = scope(now, unique)
    email = "expire#{unique}@example.com"
    ticket = unboxed(fn -> issued_ticket_candidate!(buyer_email: email) end)
    {challenge, otp} = issue(id, email, now)
    {:ok, _} = unboxed(fn -> Otp.verify(challenge.public_id, otp, now, {id, command, email}) end)

    [binding, _] =
      contend(fn -> lock_challenge(challenge.id) end, [:bind, :expire], fn
        :bind ->
          Otp.bind(challenge.public_id, ticket.ticket_issue_id, now, {id, command, email})

        :expire ->
          Repo.update_all(
            from(c in "sales_ticket_resend_challenges",
              where: c.id == ^challenge.id and c.status == "verified"
            ),
            set: [status: "expired", updated_at: now]
          )
      end)

    assert binding in [{:ok, :bound}, {:error, :invalid_or_expired}]

    row =
      unboxed(fn ->
        Repo.one!(
          from c in "sales_ticket_resend_challenges",
            where: c.id == ^challenge.id,
            select: map(c, [:status, :ticket_issue_id])
        )
      end)

    assert row.status == "expired"

    assert row.ticket_issue_id ==
             if(binding == {:ok, :bound}, do: ticket.ticket_issue_id, else: nil)
  end

  defp issue(id, email, now) do
    unboxed(fn ->
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

      {challenge, otp}
    end)
  end

  defp scope(now, unique) do
    wa = Integer.to_string(27_000_000_000 + unique)

    id =
      unboxed(fn ->
        %{rows: [[id]]} =
          Repo.query!(
            "INSERT INTO sales_conversations (phone_e164, wa_id, inserted_at, updated_at) VALUES ($1, $2, $3, $3) RETURNING id",
            ["+" <> wa, wa, now]
          )

        id
      end)

    {id,
     %MessageCommand{
       provider: "meta",
       provider_message_id: "test",
       phone_e164: "+" <> wa,
       wa_id: wa,
       message_type: "text",
       received_at: now,
       raw_payload_hash: "test",
       correlation_id: "test"
     }}
  end

  defp lock_challenge(id),
    do:
      Repo.query!("SELECT id FROM sales_ticket_resend_challenges WHERE id = $1 FOR UPDATE", [id])

  defp contend(lock, inputs, fun) do
    parent = self()

    holder =
      Task.async(fn ->
        unboxed(fn ->
          Repo.transaction(fn ->
            %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
            lock.()
            send(parent, {:holder, self(), pid})

            receive do
              :release -> :ok
            after
              10_000 -> raise "lock holder timed out"
            end
          end)
        end)
      end)

    assert_receive {:holder, holder_pid, holder_db}, 5_000

    tasks =
      Enum.map(inputs, fn input ->
        Task.async(fn ->
          unboxed(fn ->
            %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
            send(parent, {:contender, self(), pid})

            receive do
              :start -> fun.(input)
            after
              5_000 -> raise "start timed out"
            end
          end)
        end)
      end)

    workers =
      for _ <- tasks do
        assert_receive {:contender, pid, db_pid}, 5_000
        {pid, db_pid}
      end

    db_pids = Enum.map(workers, &elem(&1, 1))
    assert length(Enum.uniq([holder_db | db_pids])) == length(db_pids) + 1
    Enum.each(workers, fn {pid, _} -> send(pid, :start) end)
    await_blocked(db_pids, holder_db, System.monotonic_time(:millisecond) + 5_000)
    send(holder_pid, :release)
    assert {:ok, :ok} = Task.await(holder, 10_000)
    Task.await_many(tasks, 15_000)
  end

  defp await_blocked(pids, holder, deadline) do
    states =
      unboxed(fn ->
        Repo.query!(
          "SELECT pid, pg_blocking_pids(pid), wait_event_type, wait_event FROM pg_stat_activity WHERE pid = ANY($1::int[])",
          [pids]
        ).rows
      end)

    blockers = Map.new(states, fn [pid, blocked_by, _type, _event] -> {pid, blocked_by} end)

    cond do
      Enum.all?(pids, &blocked_by_holder?(&1, holder, blockers, MapSet.new())) ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        flunk(
          "contenders did not reach held database lock; holder=#{holder} states=#{inspect(states)}"
        )

      true ->
        Process.sleep(10)
        await_blocked(pids, holder, deadline)
    end
  end

  # A PostgreSQL lock waiter may itself block a later waiter in the queue.
  # Reject unknown, missing, or cyclic paths rather than accepting any blocker.
  defp blocked_by_holder?(pid, holder, _blockers, _seen) when pid == holder, do: true

  defp blocked_by_holder?(pid, holder, blockers, seen) do
    case {Map.get(blockers, pid), MapSet.member?(seen, pid)} do
      {blockers_for_pid, false} when is_list(blockers_for_pid) and blockers_for_pid != [] ->
        seen = MapSet.put(seen, pid)
        Enum.all?(blockers_for_pid, &blocked_by_holder?(&1, holder, blockers, seen))

      _ ->
        false
    end
  end

  defp unboxed(fun), do: Sandbox.unboxed_run(Repo, fun)
end
