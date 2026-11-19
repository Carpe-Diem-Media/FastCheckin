defmodule FastCheck.Messaging.WhatsApp.ResendTicketE2ETest do
  use FastCheck.DataCase, async: false
  use Oban.Testing, repo: FastCheck.Repo

  import Ecto.Query
  import ExUnit.CaptureLog
  import FastCheck.TicketResendFixtures
  import Swoosh.TestAssertions

  alias Ash.Changeset
  alias Ash.Query
  alias FastCheck.Messaging.WhatsApp.ConversationStateMachine
  alias FastCheck.Messaging.WhatsApp.MessageCommand
  alias FastCheck.Messaging.WhatsApp.WebhookTestSupport
  alias FastCheck.Repo
  alias FastCheck.Sales.Conversation
  alias FastCheck.Sales.TicketPage
  alias FastCheck.Workers.SendWhatsAppTicketLinkWorker

  setup :set_swoosh_global

  setup do
    WebhookTestSupport.flush_redis_keys!()
    cleanup = WebhookTestSupport.setup_whatsapp!()

    on_exit(fn ->
      WebhookTestSupport.flush_redis_keys!()
      cleanup.()
    end)

    {:ok, conversation: insert_conversation!()}
  end

  test "customer completes WhatsApp resend flow and receives audited secure ticket link", %{
    conversation: conversation
  } do
    test_pid = self()

    candidate =
      issued_ticket_candidate!(buyer_email: "resend@example.com", buyer_name: "Jamie Smith")

    assert nil == order_conversation_id(candidate.sales_order_id)

    {{verified, otp}, flow_log} =
      capture_result_and_log(fn ->
        conversation
        |> progress("hi", "e2e-1")
        |> progress("1", "e2e-2")
        |> progress("3", "e2e-3")
        |> progress("resend@example.com", "e2e-5")
        |> then(fn result ->
          otp = extract_single_otp_from_email!()
          assert {:ok, verified} = handle(result.conversation, otp, "wamid.e2e-6")
          refute verified.response_body =~ "http://"
          refute verified.response_body =~ "https://"
          refute verified.response_body =~ "/t/"
          refute verified.response_body =~ otp
          {verified, otp}
        end)
      end)

    assert verified.conversation.state == "verified_resend_delivery_queued"
    assert verified.response_body =~ "gereed"

    challenge =
      Repo.one!(
        from c in "sales_ticket_resend_challenges",
          where: c.status == "verified",
          select:
            map(c, [
              :id,
              :public_id,
              :sales_order_id,
              :ticket_issue_id,
              :status,
              :consumed_at
            ])
      )

    assert challenge.consumed_at == nil
    assert_safe_flow_log!(flow_log, candidate, challenge.public_id, otp)

    intent_id =
      Repo.one!(
        from i in "sales_ticket_delivery_intents",
          where: i.ticket_resend_challenge_id == ^challenge.id,
          select: i.id
      )

    assert_enqueued(
      worker: SendWhatsAppTicketLinkWorker,
      args: %{"ticket_delivery_intent_id" => intent_id}
    )

    Application.put_env(:fastcheck, :whatsapp_request_fun, fn request ->
      send(test_pid, {:whatsapp_request, request})

      {:ok,
       %Req.Response{
         status: 200,
         body: Jason.encode!(%{"messages" => [%{"id" => "wamid.e2e-resend-ticket"}]})
       }}
    end)

    worker_log =
      capture_log(fn ->
        assert :ok =
                 perform_job(SendWhatsAppTicketLinkWorker, %{
                   "ticket_delivery_intent_id" => intent_id
                 })
      end)

    assert_received {:whatsapp_request, request}
    assert request.options.json["type"] == "text"
    refute Map.has_key?(request.options.json, "document")
    refute Map.has_key?(request.options.json, "attachment")
    refute Map.has_key?(request.options.json, "filename")

    body = request.options.json["text"]["body"]
    token = extract_ticket_link_token!(body)
    assert_fragment_ticket_url!(body, token)
    assert %{state: :valid} = TicketPage.resolve(token)
    assert_safe_worker_log!(worker_log, candidate, challenge.public_id, otp, token)

    assert %{status: "consumed", consumed_at: consumed_at} =
             resend_challenge_snapshot(challenge.id)

    assert consumed_at

    assert [
             %{
               status: "provider_accepted",
               delivery_reason: "verified_ticket_resend",
               ticket_resend_challenge_id: challenge_id,
               provider_message_id: "wamid.e2e-resend-ticket"
             }
           ] =
             Repo.all(
               from d in "sales_delivery_attempts",
                 where: d.ticket_issue_id == ^challenge.ticket_issue_id,
                 select:
                   map(d, [
                     :status,
                     :delivery_reason,
                     :ticket_resend_challenge_id,
                     :provider_message_id
                   ])
             )

    assert challenge_id == challenge.id
    assert nil == order_conversation_id(candidate.sales_order_id)
  end

  test "verified resend uses the current conversation, not the original purchase binding", %{
    conversation: conversation
  } do
    test_pid = self()

    candidate =
      issued_ticket_candidate!(buyer_email: "resend@example.com", buyer_name: "Jamie Smith")

    %{rows: [[purchase_conversation_id]]} =
      Repo.query!(
        """
        INSERT INTO sales_conversations
          (phone_e164, wa_id, preferred_language, state, state_data, needs_human, inserted_at, updated_at)
        VALUES ('+27123456789', '27123456789', 'en', 'ticket_issued', '{}', false, now(), now())
        RETURNING id
        """,
        []
      )

    Repo.update_all(
      from(o in "sales_orders", where: o.id == ^candidate.sales_order_id),
      set: [
        sales_conversation_id: purchase_conversation_id,
        source_channel: "web",
        buyer_phone: "+27123456789"
      ]
    )

    assert purchase_conversation_id != conversation.id

    conversation
    |> progress("hi", "different-conv-1")
    |> progress("1", "different-conv-2")
    |> progress("3", "different-conv-3")
    |> progress("resend@example.com", "different-conv-5")
    |> then(fn result ->
      otp = extract_single_otp_from_email!()
      assert {:ok, verified} = handle(result.conversation, otp, "wamid.different-conv-6")
      assert verified.conversation.state == "verified_resend_delivery_queued"
    end)

    challenge_id =
      Repo.one!(
        from c in "sales_ticket_resend_challenges",
          where: c.status == "verified",
          select: c.id
      )

    intent_id =
      Repo.one!(
        from i in "sales_ticket_delivery_intents",
          where: i.ticket_resend_challenge_id == ^challenge_id,
          select: i.id
      )

    Application.put_env(:fastcheck, :whatsapp_request_fun, fn request ->
      send(test_pid, {:whatsapp_request, request})

      {:ok,
       %Req.Response{
         status: 200,
         body: Jason.encode!(%{"messages" => [%{"id" => "wamid.different-conv-resend"}]})
       }}
    end)

    assert :ok =
             perform_job(SendWhatsAppTicketLinkWorker, %{
               "ticket_delivery_intent_id" => intent_id
             })

    assert_received {:whatsapp_request, request}
    resend_body = request.options.json["text"]["body"]
    resend_token = extract_ticket_link_token!(resend_body)
    assert_fragment_ticket_url!(resend_body, resend_token)

    assert %{status: "consumed", consumed_at: consumed_at} =
             resend_challenge_snapshot(challenge_id)

    assert consumed_at
    assert order_conversation_id(candidate.sales_order_id) == purchase_conversation_id

    assert [
             %{
               status: "provider_accepted",
               provider_message_id: "wamid.different-conv-resend",
               delivery_reason: "verified_ticket_resend"
             }
           ] =
             Repo.all(
               from d in "sales_delivery_attempts",
                 where: d.ticket_delivery_intent_id == ^intent_id,
                 select: map(d, [:status, :provider_message_id, :delivery_reason])
             )
  end

  test "verified selection is bounded and never discloses candidates before OTP", %{
    conversation: conversation
  } do
    for count <- [2, 9, 10] do
      email = "bounded-#{count}@example.com"

      for n <- 1..count do
        issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Guest#{n}")
      end

      current =
        Conversation
        |> Query.for_read(:get_by_id, %{id: conversation.id})
        |> Ash.read_one!(authorize?: false)

      {:ok, menu} = handle(current, "#", "wamid.bound-menu-#{count}")
      {:ok, email_prompt} = handle(menu.conversation, "3", "wamid.bound-start-#{count}")
      {:ok, otp_prompt} = handle(email_prompt.conversation, email, "wamid.bound-email-#{count}")
      refute otp_prompt.response_body =~ "Guest"
      otp = extract_single_otp_from_email!()
      {:ok, result} = handle(otp_prompt.conversation, otp, "wamid.bound-otp-#{count}")

      if count <= 9 do
        assert result.conversation.state == "selecting_resend_ticket"
        assert result.response_body =~ "Guest1"
        refute result.response_body =~ email
        assert String.length(result.response_body) <= 4096
        [code | _] = choice_codes(result.response_body)
        {:ok, selected} = handle(result.conversation, code, "wamid.bound-select-#{count}")
        assert selected.conversation.state == "verified_resend_delivery_queued"
      else
        refute result.response_body =~ "Guest"
        assert result.response_body =~ "organiseerder"
      end
    end
  end

  test "a changed candidate snapshot cannot reinterpret a numeric selection", %{
    conversation: conversation
  } do
    email = "stale@example.com"
    first = issued_ticket_candidate!(buyer_email: email, attendee_first_name: "First")
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Second")

    result =
      conversation
      |> progress("hi", "stale-1")
      |> progress("1", "stale-2")
      |> progress("3", "stale-3")
      |> progress(email, "stale-4")

    otp = extract_single_otp_from_email!()
    {:ok, choices} = handle(result.conversation, otp, "wamid.stale-5")
    assert choices.conversation.state == "selecting_resend_ticket"

    Repo.update_all(from(t in "sales_ticket_issues", where: t.id == ^first.ticket_issue_id),
      set: [status: "revoked", revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )

    code =
      Enum.find(choice_codes(choices.response_body), fn code ->
        digest =
          :crypto.hash(
            :sha256,
            "resend-choice:" <>
              choices.conversation.state_data["resend_challenge_public_id"] <> ":" <> code
          )
          |> Base.encode16(case: :lower)

        choices.conversation.state_data["resend_snapshot"]["choices"][digest] ==
          first.ticket_issue_id
      end)

    assert code
    {:ok, declined} = handle(choices.conversation, code, "wamid.stale-6")
    assert declined.response_body =~ "organiseerder"
    refute_enqueued(worker: SendWhatsAppTicketLinkWorker)
  end

  test "duplicate selection queues only one intent and exit expires a pending challenge", %{
    conversation: conversation
  } do
    email = "duplicates@example.com"
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "First")
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Second")

    request =
      conversation
      |> progress("hi", "dup-1")
      |> progress("1", "dup-2")
      |> progress("3", "dup-3")
      |> progress(email, "dup-4")

    otp = extract_single_otp_from_email!()
    {:ok, choices} = handle(request.conversation, otp, "wamid.dup-5")
    [code | _] = choice_codes(choices.response_body)
    refute inspect(choices) =~ code
    {:ok, queued} = handle(choices.conversation, code, "wamid.dup-6")
    assert queued.conversation.state == "verified_resend_delivery_queued"
    assert {:ok, %{send_reply?: false}} = handle(queued.conversation, code, "wamid.dup-6")

    assert Repo.one!(
             from i in "sales_ticket_delivery_intents",
               where: i.purpose == "verified_ticket_resend",
               select: count(i.id)
           ) == 1

    {:ok, menu} = handle(queued.conversation, "#", "wamid.dup-7")
    {:ok, prompt} = handle(menu.conversation, "3", "wamid.dup-8")
    {:ok, pending} = handle(prompt.conversation, "other@example.com", "wamid.dup-9")
    public_id = pending.conversation.state_data["resend_challenge_public_id"]
    {:ok, exited} = handle(pending.conversation, "0", "wamid.dup-10")
    assert exited.conversation.state == "main_menu"

    assert Repo.one!(
             from c in "sales_ticket_resend_challenges",
               where: c.public_id == ^public_id,
               select: c.status
           ) == "expired"
  end

  test "competing choices cannot bind different tickets", %{conversation: conversation} do
    email = "racing@example.com"
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "First")
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Second")

    pending =
      conversation
      |> progress("hi", "race-1")
      |> progress("1", "race-2")
      |> progress("3", "race-3")
      |> progress(email, "race-4")

    otp = extract_single_otp_from_email!()
    {:ok, choices} = handle(pending.conversation, otp, "wamid.race-5")
    [first, second] = choice_codes(choices.response_body)

    results =
      [first, second]
      |> Enum.with_index()
      |> Enum.map(fn {code, n} ->
        Task.async(fn ->
          ConversationStateMachine.handle_inbound(
            command(choices.conversation, code, "wamid.race-choice-#{n}"),
            choices.conversation
          )
        end)
      end)
      |> Enum.map(&Task.await(&1, 15_000))

    assert Enum.any?(
             results,
             &match?({:ok, %{conversation: %{state: "verified_resend_delivery_queued"}}}, &1)
           )

    assert Repo.one!(
             from i in "sales_ticket_delivery_intents",
               where: i.purpose == "verified_ticket_resend",
               select: count(i.id)
           ) == 1
  end

  test "challenge expiry invalidates its choice snapshot before binding", %{
    conversation: conversation
  } do
    email = "expired-choice@example.com"
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "First")
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Second")

    pending =
      conversation
      |> progress("hi", "choice-expiry-1")
      |> progress("1", "choice-expiry-2")
      |> progress("3", "choice-expiry-3")
      |> progress(email, "choice-expiry-4")

    otp = extract_single_otp_from_email!()
    {:ok, choices} = handle(pending.conversation, otp, "wamid.choice-expiry-5")
    [code | _] = choice_codes(choices.response_body)
    public_id = choices.conversation.state_data["resend_challenge_public_id"]

    Repo.update_all(from(c in "sales_ticket_resend_challenges", where: c.public_id == ^public_id),
      set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :second)]
    )

    {:ok, expired} = handle(choices.conversation, code, "wamid.choice-expiry-6")
    assert expired.conversation.state_data["resend_snapshot"]["status"] == "expired"

    assert Repo.one!(
             from c in "sales_ticket_resend_challenges",
               where: c.public_id == ^public_id,
               select: c.status
           ) == "expired"

    refute_enqueued(worker: SendWhatsAppTicketLinkWorker)
  end

  test "selection racing exit never creates multiple resend intents", %{
    conversation: conversation
  } do
    email = "race-exit@example.com"
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "First")
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Second")

    pending =
      conversation
      |> progress("hi", "exit-race-1")
      |> progress("1", "exit-race-2")
      |> progress("3", "exit-race-3")
      |> progress(email, "exit-race-4")

    otp = extract_single_otp_from_email!()
    {:ok, choices} = handle(pending.conversation, otp, "wamid.exit-race-5")
    [code | _] = choice_codes(choices.response_body)

    results =
      [code, "0"]
      |> Enum.with_index()
      |> Enum.map(fn {text, n} ->
        Task.async(fn ->
          ConversationStateMachine.handle_inbound(
            command(choices.conversation, text, "wamid.exit-race-#{n}"),
            choices.conversation
          )
        end)
      end)
      |> Enum.map(&Task.await(&1, 15_000))

    assert length(results) == 2

    assert Repo.one!(
             from i in "sales_ticket_delivery_intents",
               where: i.purpose == "verified_ticket_resend",
               select: count(i.id)
           ) <= 1

    assert Repo.one!(
             from c in "sales_ticket_resend_challenges",
               where:
                 c.public_id == ^choices.conversation.state_data["resend_challenge_public_id"],
               select: c.status
           ) in ["expired", "verified"]
  end

  test "choice mapping and encrypted reply are frozen together before delivery", %{
    conversation: conversation
  } do
    email = "frozen@example.com"
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "First")
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Second")

    pending =
      conversation
      |> progress("hi", "frozen-1")
      |> progress("1", "frozen-2")
      |> progress("3", "frozen-3")
      |> progress(email, "frozen-4")

    otp = extract_single_otp_from_email!()

    command = %MessageCommand{
      provider: "meta",
      provider_message_id: "wamid.frozen-5",
      phone_e164: "+27821234567",
      wa_id: "27821234567",
      message_type: "text",
      text_body: otp,
      received_at: DateTime.utc_now() |> DateTime.truncate(:second),
      raw_payload_hash: "synthetic",
      correlation_id: "synthetic"
    }

    assert {:ok, result} = ConversationStateMachine.handle_inbound(command, pending.conversation)
    [code | _] = choice_codes(result.response_body)
    stored = result.conversation.state_data["pending_reply"]
    assert stored["status"] == "reply_pending"
    assert {:ok, body} = FastCheck.Crypto.decrypt(stored["ciphertext"])
    assert body == result.response_body
    refute inspect(result.conversation.state_data) =~ code
    assert {:ok, repeated} = ConversationStateMachine.handle_inbound(command, result.conversation)
    refute repeated.send_reply?
    assert repeated.conversation.state_data["pending_reply"]["ciphertext"] == stored["ciphertext"]
  end

  test "inbound worker reuses a frozen menu after provider acceptance and process loss", %{
    conversation: conversation
  } do
    email = "frozen-recovery@example.com"
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "First")
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Second")

    pending =
      conversation
      |> progress("hi", "frozen-recovery-1")
      |> progress("1", "frozen-recovery-2")
      |> progress("3", "frozen-recovery-3")
      |> progress(email, "frozen-recovery-4")

    otp = extract_single_otp_from_email!()
    cmd = command(pending.conversation, otp, "wamid.frozen-recovery-5")
    assert {:ok, result} = ConversationStateMachine.handle_inbound(cmd, pending.conversation)
    frozen = result.conversation.state_data["pending_reply"]["ciphertext"]
    mapping = result.conversation.state_data["resend_snapshot"]
    assert {:ok, expected} = FastCheck.Crypto.decrypt(frozen)
    codes = choice_codes(expected)
    assert length(codes) == 2

    for code <- codes do
      digest =
        :crypto.hash(:sha256, "resend-choice:" <> mapping["challenge"] <> ":" <> code)
        |> Base.encode16(case: :lower)

      assert is_integer(mapping["choices"][digest])
    end

    args = %{
      "conversation_id" => conversation.id,
      "provider_message_id" => cmd.provider_message_id,
      "correlation_id" => cmd.correlation_id,
      "message_type" => "text"
    }

    parent = self()
    # The provider can accept before the worker dies; recovery may send the same menu twice.
    Application.put_env(:fastcheck, :whatsapp_request_fun, fn request ->
      send(parent, {:fake_provider_accepted, request.options.json["text"]["body"]})
      Process.exit(self(), :kill)
    end)

    {pid, monitor} =
      spawn_monitor(fn -> perform_job(FastCheck.Workers.WhatsAppInboundWorker, args) end)

    assert_receive {:fake_provider_accepted, ^expected}, 5_000
    assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}, 5_000

    after_loss =
      Conversation
      |> Query.for_read(:get_by_id, %{id: conversation.id})
      |> Ash.read_one!(authorize?: false)

    assert after_loss.state_data["pending_reply"]["ciphertext"] == frozen
    assert after_loss.state_data["resend_snapshot"] == mapping

    Application.put_env(:fastcheck, :whatsapp_request_fun, fn request ->
      send(parent, {:retried_menu, request.options.json["text"]["body"]})

      {:ok,
       %Req.Response{
         status: 200,
         body: Jason.encode!(%{"messages" => [%{"id" => "wamid.frozen-recovery-out"}]})
       }}
    end)

    assert :ok = perform_job(FastCheck.Workers.WhatsAppInboundWorker, args)
    assert_receive {:retried_menu, ^expected}

    after_retry =
      Conversation
      |> Query.for_read(:get_by_id, %{id: conversation.id})
      |> Ash.read_one!(authorize?: false)

    assert after_retry.state_data["resend_snapshot"] == mapping
    assert after_retry.state_data["pending_reply"]["status"] == "reply_sent"
    assert is_nil(after_retry.state_data["pending_reply"]["ciphertext"])
  end

  test "zero eligible tickets returns safe help after verification", %{conversation: conversation} do
    result =
      conversation
      |> progress("hi", "none-1")
      |> progress("1", "none-2")
      |> progress("3", "none-3")
      |> progress("nobody@example.com", "none-4")

    otp = extract_single_otp_from_email!()
    {:ok, response} = handle(result.conversation, otp, "wamid.none-5")
    assert response.response_body =~ "organiseerder"
    refute_enqueued(worker: SendWhatsAppTicketLinkWorker)
  end

  test "an old snapshot code and bare number cannot select from a new list", %{
    conversation: conversation
  } do
    email = "replace@example.com"
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "First")
    issued_ticket_candidate!(buyer_email: email, attendee_first_name: "Second")

    initial =
      conversation
      |> progress("hi", "replace-1")
      |> progress("1", "replace-2")
      |> progress("3", "replace-3")
      |> progress(email, "replace-4")

    otp = extract_single_otp_from_email!()
    {:ok, first} = handle(initial.conversation, otp, "wamid.replace-5")
    [old_code | _] = choice_codes(first.response_body)
    {:ok, menu} = handle(first.conversation, "0", "wamid.replace-6")
    assert menu.conversation.state_data["resend_snapshot"]["status"] == "invalidated"
    {:ok, prompt} = handle(menu.conversation, "3", "wamid.replace-7")
    {:ok, pending} = handle(prompt.conversation, email, "wamid.replace-8")
    otp2 = extract_single_otp_from_email!()
    {:ok, second} = handle(pending.conversation, otp2, "wamid.replace-9")
    refute old_code in choice_codes(second.response_body)
    {:ok, invalid} = handle(second.conversation, old_code, "wamid.replace-10")
    assert invalid.conversation.state == "selecting_resend_ticket"
    {:ok, numeric} = handle(invalid.conversation, "1", "wamid.replace-11")
    assert numeric.conversation.state == "selecting_resend_ticket"
    refute_enqueued(worker: SendWhatsAppTicketLinkWorker)
  end

  defp choice_codes(body), do: Regex.scan(~r/FC-[A-Za-z0-9_-]{22}/, body) |> List.flatten()

  defp progress(%{conversation: conversation}, text, suffix),
    do: progress(conversation, text, suffix)

  defp progress(%Conversation{} = conversation, text, suffix) do
    assert {:ok, result} = handle(conversation, text, "wamid.progress-#{suffix}")
    result
  end

  defp handle(conversation, text, provider_message_id) do
    command = command(conversation, text, provider_message_id)

    case ConversationStateMachine.handle_inbound(command, conversation) do
      {:ok, %{send_reply?: true, conversation: updated_conversation} = result} ->
        assert {:ok, sent_conversation} =
                 updated_conversation
                 |> Changeset.for_update(
                   :mark_reply_sent,
                   %{
                     provider_message_id: provider_message_id,
                     outbound_message_id: "test-outbound-#{provider_message_id}",
                     sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
                   },
                   actor: %{actor_type: :system, actor_id: "resend_ticket_e2e_test"}
                 )
                 |> Ash.update(authorize?: false)

        {:ok, %{result | conversation: sent_conversation}}

      other ->
        other
    end
  end

  defp command(conversation, text, provider_message_id) do
    %MessageCommand{
      provider: "meta",
      provider_message_id: provider_message_id,
      phone_e164: "+27821234567",
      wa_id: "27821234567",
      message_type: "text",
      text_body: text,
      received_at:
        DateTime.utc_now()
        |> DateTime.add(
          if(conversation.state == "selecting_resend_ticket", do: 2, else: 0),
          :second
        )
        |> DateTime.truncate(:second),
      raw_payload_hash: "hash-#{provider_message_id}",
      correlation_id: "corr-#{provider_message_id}",
      metadata: %{}
    }
  end

  defp insert_conversation! do
    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO sales_conversations
          (phone_e164, wa_id, preferred_language, state, state_data, needs_human, inserted_at, updated_at)
        VALUES
          ('+27821234567', '27821234567', 'af', 'new', '{}', false, now(), now())
        RETURNING id
        """,
        []
      )

    Conversation
    |> Query.for_read(:get_by_id, %{id: id})
    |> Ash.read_one!(authorize?: false)
  end

  defp extract_single_otp_from_email! do
    assert_received {:email, email}

    case Regex.run(~r/\b\d{6}\b/, email.text_body || "") do
      [otp] -> otp
      _ -> flunk("expected OTP email body to contain a six-digit code")
    end
  end

  defp extract_ticket_link_token!(body) when is_binary(body) do
    uri = URI.parse(extract_ticket_link_url!(body))

    case uri.fragment do
      fragment when is_binary(fragment) and fragment != "" -> fragment
      _ -> flunk("expected WhatsApp body to contain a /t#<delivery-token> ticket link")
    end
  end

  defp extract_ticket_link_url!(body) when is_binary(body) do
    case Regex.run(~r{https?://[^\s]+/t#[^\s]+}, body) do
      [url] -> url
      _ -> flunk("expected WhatsApp body to contain a secure ticket URL")
    end
  end

  defp assert_fragment_ticket_url!(body, token) when is_binary(body) and is_binary(token) do
    uri = URI.parse(extract_ticket_link_url!(body))
    endpoint = URI.parse(FastCheckWeb.Endpoint.url())

    assert uri.scheme == endpoint.scheme
    assert uri.host == endpoint.host
    assert uri.path == "/t"
    assert uri.query == nil
    assert uri.fragment == token
    refute String.contains?(body, "/t/#{token}")
    refute String.contains?(body, "?token=")
    refute String.contains?(body, "?delivery_token=")
  end

  defp resend_challenge_snapshot(challenge_id) do
    Repo.one!(
      from c in "sales_ticket_resend_challenges",
        where: c.id == ^challenge_id,
        select: map(c, [:status, :consumed_at])
    )
  end

  defp order_conversation_id(order_id) do
    Repo.one!(
      from o in "sales_orders",
        where: o.id == ^order_id,
        select: o.sales_conversation_id
    )
  end

  defp capture_result_and_log(fun) do
    ref = make_ref()

    log =
      capture_log(fn ->
        send(self(), {ref, fun.()})
      end)

    assert_received {^ref, result}
    {result, log}
  end

  defp assert_safe_flow_log!(log, candidate, public_id, otp) do
    refute log =~ otp
    refute log =~ public_id
    refute log =~ candidate.buyer_email
    refute log =~ candidate.buyer_name
    refute log =~ candidate.ticket_code
    refute log =~ "+27821234567"
    refute log =~ "/t/"
    refute log =~ "delivery_token"
    refute log =~ "qr_token"
    refute log =~ "provider_payload"
  end

  defp assert_safe_worker_log!(log, candidate, public_id, otp, token) do
    assert_safe_flow_log!(log, candidate, public_id, otp)
    refute log =~ token
    refute log =~ "delivery_token_hash"
    refute log =~ "qr_token_hash"
  end
end
