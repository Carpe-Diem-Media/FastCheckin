defmodule FastCheck.Tickets.Resend.EmailFirstTest do
  use FastCheck.DataCase, async: false

  import Ecto.Query
  import FastCheck.TicketResendFixtures
  alias FastCheck.Messaging.WhatsApp.MessageCommand
  alias FastCheck.Repo
  alias FastCheck.Tickets.Resend.EmailOtp
  alias FastCheck.Tickets.Resend.{Hash, Otp}

  test "email-first issuance sends to normalized email without an order" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO sales_conversations (phone_e164, wa_id, inserted_at, updated_at) VALUES ($1, $2, $3, $3) RETURNING id",
        ["+27821234567", "27821234567", now]
      )

    command = %MessageCommand{
      provider: "meta",
      provider_message_id: "test",
      phone_e164: "+27821234567",
      wa_id: "27821234567",
      message_type: "text",
      received_at: now,
      raw_payload_hash: "test",
      correlation_id: "test"
    }

    deliver = fn email ->
      send(self(), {:delivered, email})
      {:ok, %{}}
    end

    assert {:ok, result} =
             EmailOtp.request_email_first(" NO-TICKET@example.com ", {id, command},
               deliver_fun: deliver
             )

    assert result.public_status == :accepted
    assert_receive {:delivered, email}
    assert {"", "no-ticket@example.com"} in email.to

    row =
      Repo.one!(
        from c in "sales_ticket_resend_challenges",
          where: c.public_id == ^result.challenge_public_id,
          select: map(c, [:sales_order_id, :ticket_issue_id, :request_name_hash, :candidate_hash])
      )

    assert row == %{
             sales_order_id: nil,
             ticket_issue_id: nil,
             request_name_hash: nil,
             candidate_hash: nil
           }

    issued_ticket_candidate!(buyer_email: "many@example.com")
    issued_ticket_candidate!(buyer_email: "many@example.com")

    assert {:ok, many} =
             EmailOtp.request_email_first("many@example.com", {id, command},
               deliver_fun: fn _ -> {:error, :synthetic_failure} end
             )

    assert many.public_status == result.public_status
    assert many.customer_message == result.customer_message
    refute inspect(many) =~ "many@example.com"
    refute inspect(result) =~ "no-ticket@example.com"
  end

  test "email-first verification requires the persisted conversation scope" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{rows: [[conversation_id]]} =
      Repo.query!(
        "INSERT INTO sales_conversations (phone_e164, wa_id, inserted_at, updated_at) VALUES ($1, $2, $3, $3) RETURNING id",
        ["+27821234567", "27821234567", now]
      )

    attrs = %{
      conversation_id: conversation_id,
      source_hash: Hash.source(%{conversation_id: conversation_id}),
      request_email_hash: Hash.email("owner@example.com")
    }

    assert {:ok, challenge, otp} = Otp.issue(attrs, now, return_otp?: true)

    command = %MessageCommand{
      provider: "meta",
      provider_message_id: "test",
      phone_e164: "+27821234567",
      wa_id: "27821234567",
      message_type: "text",
      received_at: now,
      raw_payload_hash: "test",
      correlation_id: "test"
    }

    assert {:error, :invalid_or_expired} = Otp.verify(challenge.public_id, otp, now)
    assert {:error, :invalid_or_expired} = Otp.verify(challenge.public_id, otp, now, nil)

    assert {:error, :invalid_or_expired} =
             Otp.verify(
               challenge.public_id,
               otp,
               now,
               {conversation_id + 1, command, "owner@example.com"}
             )

    assert {:error, :invalid_or_expired} =
             Otp.verify(
               challenge.public_id,
               otp,
               now,
               {conversation_id, %{command | wa_id: "wrong"}, "owner@example.com"}
             )

    assert {:error, :invalid_or_expired} =
             Otp.verify(
               challenge.public_id,
               otp,
               now,
               {conversation_id, command, "other@example.com"}
             )

    Repo.query!("UPDATE sales_ticket_resend_challenges SET source_hash = $1 WHERE id = $2", [
      "wrong",
      challenge.id
    ])

    before_scope_rejection =
      Repo.one!(
        from c in "sales_ticket_resend_challenges",
          where: c.id == ^challenge.id,
          select:
            map(c, [
              :status,
              :updated_at,
              :failed_attempt_count,
              :verified_at,
              :sales_order_id,
              :ticket_issue_id
            ])
      )

    assert {:error, :invalid_or_expired} =
             Otp.verify(
               challenge.public_id,
               otp,
               now,
               {conversation_id, command, "owner@example.com"}
             )

    assert before_scope_rejection ==
             Repo.one!(
               from c in "sales_ticket_resend_challenges",
                 where: c.id == ^challenge.id,
                 select:
                   map(c, [
                     :status,
                     :updated_at,
                     :failed_attempt_count,
                     :verified_at,
                     :sales_order_id,
                     :ticket_issue_id
                   ])
             )

    Repo.query!("UPDATE sales_ticket_resend_challenges SET source_hash = $1 WHERE id = $2", [
      Hash.source(%{conversation_id: conversation_id}),
      challenge.id
    ])

    assert Repo.one!(
             from c in "sales_ticket_resend_challenges",
               where: c.id == ^challenge.id,
               select: c.status
           ) == "pending"

    assert {:ok, _} =
             Otp.verify(
               challenge.public_id,
               otp,
               now,
               {conversation_id, command, "owner@example.com"}
             )

    assert {:error, :already_verified} =
             Otp.verify(
               challenge.public_id,
               otp,
               now,
               {conversation_id, command, "owner@example.com"}
             )

    candidate = issued_ticket_candidate!(buyer_email: "owner@example.com")

    assert {:ok, :bound} =
             Otp.bind(
               challenge.public_id,
               candidate.ticket_issue_id,
               now,
               {conversation_id, command, "owner@example.com"}
             )

    assert {:ok, :already_bound} =
             Otp.bind(
               challenge.public_id,
               candidate.ticket_issue_id,
               now,
               {conversation_id, command, "owner@example.com"}
             )

    other = issued_ticket_candidate!(buyer_email: "owner@example.com")

    assert {:error, :invalid_or_expired} =
             Otp.bind(
               challenge.public_id,
               other.ticket_issue_id,
               now,
               {conversation_id, command, "owner@example.com"}
             )

    assert {:error, :invalid_or_expired} = Otp.verify(challenge.public_id, otp, now)

    assert {:error, :already_verified} =
             Otp.verify(
               challenge.public_id,
               otp,
               now,
               {conversation_id, command, "owner@example.com"}
             )

    for terminal <- ["expired", "consumed"] do
      Repo.query!("UPDATE sales_ticket_resend_challenges SET status = $1 WHERE id = $2", [
        terminal,
        challenge.id
      ])

      before =
        Repo.one!(
          from c in "sales_ticket_resend_challenges",
            where: c.id == ^challenge.id,
            select:
              map(c, [
                :status,
                :updated_at,
                :failed_attempt_count,
                :ticket_issue_id,
                :sales_order_id
              ])
        )

      assert {:error, :invalid_or_expired} = Otp.verify(challenge.public_id, otp, now)

      assert before ==
               Repo.one!(
                 from c in "sales_ticket_resend_challenges",
                   where: c.id == ^challenge.id,
                   select:
                     map(c, [
                       :status,
                       :updated_at,
                       :failed_attempt_count,
                       :ticket_issue_id,
                       :sales_order_id
                     ])
               )

      assert {:error, :invalid_or_expired} =
               Otp.bind(
                 challenge.public_id,
                 candidate.ticket_issue_id,
                 now,
                 {conversation_id, command, "owner@example.com"}
               )
    end
  end

  test "binding requires verified ownership and current ticket eligibility" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO sales_conversations (phone_e164, wa_id, inserted_at, updated_at) VALUES ($1, $2, $3, $3) RETURNING id",
        ["+27821234567", "27821234567", now]
      )

    command = %MessageCommand{
      provider: "meta",
      provider_message_id: "test",
      phone_e164: "+27821234567",
      wa_id: "27821234567",
      message_type: "text",
      received_at: now,
      raw_payload_hash: "test",
      correlation_id: "test"
    }

    context = {id, command, "owner@example.com"}

    {:ok, challenge, otp} =
      Otp.issue(
        %{
          conversation_id: id,
          source_hash: Hash.source(%{conversation_id: id}),
          request_email_hash: Hash.email("owner@example.com")
        },
        now,
        return_otp?: true
      )

    own = issued_ticket_candidate!(buyer_email: "owner@example.com")
    other = issued_ticket_candidate!(buyer_email: "other@example.com")

    assert {:error, :invalid_or_expired} =
             Otp.bind(challenge.public_id, own.ticket_issue_id, now, context)

    assert {:ok, _} = Otp.verify(challenge.public_id, otp, now, context)

    assert {:error, :invalid_or_expired} =
             Otp.bind(challenge.public_id, other.ticket_issue_id, now, context)

    Repo.query!("UPDATE sales_ticket_issues SET scanner_status = 'revoked' WHERE id = $1", [
      own.ticket_issue_id
    ])

    assert {:error, :invalid_or_expired} =
             Otp.bind(challenge.public_id, own.ticket_issue_id, now, context)

    assert {:error, :invalid_or_expired} =
             Otp.bind(
               challenge.public_id,
               own.ticket_issue_id,
               DateTime.add(now, 601, :second),
               context
             )

    row =
      Repo.one!(
        from c in "sales_ticket_resend_challenges",
          where: c.id == ^challenge.id,
          select: map(c, [:status, :sales_order_id, :ticket_issue_id, :candidate_hash])
      )

    assert row == %{
             status: "verified",
             sales_order_id: nil,
             ticket_issue_id: nil,
             candidate_hash: nil
           }
  end

  test "email-first challenges enforce expiry and failure lockout" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO sales_conversations (phone_e164, wa_id, inserted_at, updated_at) VALUES ($1, $2, $3, $3) RETURNING id",
        ["+27821234567", "27821234567", now]
      )

    command = %MessageCommand{
      provider: "meta",
      provider_message_id: "test",
      phone_e164: "+27821234567",
      wa_id: "27821234567",
      message_type: "text",
      received_at: now,
      raw_payload_hash: "test",
      correlation_id: "test"
    }

    attrs = %{
      conversation_id: id,
      source_hash: Hash.source(%{conversation_id: id}),
      request_email_hash: Hash.email("owner@example.com")
    }

    context = {id, command, "owner@example.com"}
    {:ok, expired, code} = Otp.issue(attrs, now, return_otp?: true)

    assert {:error, :invalid_or_expired} =
             Otp.verify(expired.public_id, code, DateTime.add(now, 601, :second), context)

    assert Repo.one!(
             from c in "sales_ticket_resend_challenges",
               where: c.id == ^expired.id,
               select: c.status
           ) == "expired"

    {:ok, locked, code} = Otp.issue(attrs, now, return_otp?: true)
    wrong = if code == "000000", do: "111111", else: "000000"

    for _ <- 1..5,
        do:
          assert(
            {:error, :invalid_or_expired} = Otp.verify(locked.public_id, wrong, now, context)
          )

    assert {:error, :locked} = Otp.verify(locked.public_id, code, now, context)

    assert Repo.one!(
             from c in "sales_ticket_resend_challenges",
               where: c.id == ^locked.id,
               select: c.failed_attempt_count
           ) == 5
  end
end
