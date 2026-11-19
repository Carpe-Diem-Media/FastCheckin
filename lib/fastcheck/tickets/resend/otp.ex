defmodule FastCheck.Tickets.Resend.Otp do
  @moduledoc """
  OTP challenge issue and verification contract for ticket resend.

  Plaintext OTPs exist only as in-memory return values for internal callers that
  explicitly opt in. Stored values are hashes only.
  """

  import Ecto.Query

  alias Ash.Changeset
  alias FastCheck.Repo
  alias FastCheck.Messaging.WhatsApp.MessageCommand
  alias FastCheck.Sales.TicketResendChallenge
  alias FastCheck.Tickets.Resend.Hash
  alias FastCheck.Tickets.Resend.Eligibility
  alias FastCheck.Tickets.Resend.RateLimit
  alias FastCheck.Tickets.Resend.Request

  require Ash.Query

  @type issue_attrs :: %{
          optional(:sales_order_id) => integer() | nil,
          optional(:ticket_issue_id) => integer() | nil,
          optional(:conversation_id) => integer() | nil,
          required(:request_email_hash) => binary(),
          optional(:request_name_hash) => binary() | nil,
          optional(:source_hash) => binary() | nil,
          optional(:candidate_hash) => binary() | nil,
          optional(:metadata) => map()
        }

  @spec issue(issue_attrs(), DateTime.t(), keyword()) ::
          {:ok, TicketResendChallenge.t(), binary() | nil} | {:error, term()}
  def issue(attrs, now, opts \\ []) when is_map(attrs) do
    otp = generate_code()
    public_id = public_id()
    expires_at = DateTime.add(now, config(:otp_ttl_seconds), :second)

    create_attrs =
      attrs
      |> Map.take([
        :sales_order_id,
        :ticket_issue_id,
        :conversation_id,
        :request_email_hash,
        :request_name_hash,
        :source_hash,
        :candidate_hash,
        :metadata
      ])
      |> Map.merge(%{
        public_id: public_id,
        otp_hash: Hash.otp(public_id, otp),
        expires_at: expires_at
      })

    case TicketResendChallenge
         |> Changeset.for_create(:create_pending, create_attrs, actor: system_actor())
         |> Ash.create() do
      {:ok, challenge} ->
        returned_otp = if Keyword.get(opts, :return_otp?, false), do: otp, else: nil
        {:ok, challenge, returned_otp}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec issue_lookup_attempt(map(), DateTime.t()) ::
          {:ok, TicketResendChallenge.t()} | {:error, term()}
  def issue_lookup_attempt(attrs, now) when is_map(attrs) do
    expires_at = DateTime.add(now, config(:otp_ttl_seconds), :second)

    create_attrs =
      attrs
      |> Map.take([
        :sales_order_id,
        :ticket_issue_id,
        :conversation_id,
        :request_email_hash,
        :request_name_hash,
        :source_hash,
        :candidate_hash,
        :metadata
      ])
      |> Map.merge(%{
        public_id: public_id(),
        expires_at: expires_at
      })

    case TicketResendChallenge
         |> Changeset.for_create(:create_pending, create_attrs, actor: system_actor())
         |> Ash.create() do
      {:ok, challenge} -> {:ok, challenge}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec verify(binary(), binary(), DateTime.t()) ::
          {:ok, TicketResendChallenge.t()}
          | {:error, :invalid_or_expired | :locked | :already_verified}
  def verify(public_id, otp, now), do: verify_with_scope(public_id, otp, now, :legacy)

  @doc """
  Verifies an unbound challenge for a conversation and its trusted inbound command.

  The command must come from the signature-verified, account-scoped webhook pipeline.
  The locked challenge, persisted conversation and command must agree before mutation.
  """
  def verify(public_id, otp, now, {conversation_id, %MessageCommand{} = command, email}) do
    case Request.normalize_email(email) do
      {:ok, normalized} ->
        verify_with_scope(
          public_id,
          otp,
          now,
          {:conversation, conversation_id, command.wa_id, Hash.email(normalized)}
        )

      _ ->
        {:error, :invalid_or_expired}
    end
  end

  def verify(_public_id, _otp, _now, _scope), do: {:error, :invalid_or_expired}

  defp verify_with_scope(public_id, otp, now, scope)
       when is_binary(public_id) and is_binary(otp) do
    Repo.transaction(fn ->
      case fetch_challenge(public_id) do
        nil ->
          {:error, :invalid_or_expired}

        challenge ->
          if valid_scope?(challenge, scope) do
            verify_scoped(challenge, otp, now)
          else
            {:error, :invalid_or_expired}
          end
      end
    end)
    |> case do
      {:ok, {:ok, challenge}} -> {:ok, challenge}
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_with_scope(_public_id, _otp, _now, _scope), do: {:error, :invalid_or_expired}

  defp verify_scoped(%{status: status}, _otp, _now) when status in ["verified", "consumed"],
    do: {:error, :already_verified}

  defp verify_scoped(%{status: status}, _otp, _now) when status in ["blocked", "manual_review"],
    do: {:error, :locked}

  defp verify_scoped(%{status: "expired"}, _otp, _now), do: {:error, :invalid_or_expired}
  defp verify_scoped(challenge, otp, now), do: verify_pending(challenge, otp, now)

  defp valid_scope?(
         %{sales_order_id: order, ticket_issue_id: ticket, request_name_hash: name},
         :legacy
       ),
       do: is_integer(order) and is_integer(ticket) and is_binary(name)

  defp valid_scope?(challenge, {:conversation, id, wa_id, email_hash})
       when is_integer(id) and id > 0 and is_binary(wa_id) and wa_id != "" do
    challenge.conversation_id == id and
      secure_match?(challenge.request_email_hash, email_hash) and
      secure_match?(challenge.source_hash, Hash.source(%{conversation_id: id})) and
      Repo.one(
        from c in "sales_conversations",
          where: c.id == ^id and c.wa_id == ^wa_id,
          lock: "FOR SHARE",
          select: c.id
      ) == id
  end

  defp valid_scope?(_challenge, _scope), do: false

  @doc """
  Binds one eligible ticket to a verified email-first challenge under its row lock.

  The caller supplies the same trusted webhook context used for verification.
  The challenge remains verified for the existing delivery worker to consume.
  """
  def bind(public_id, ticket_id, now, {id, %MessageCommand{} = command, email})
      when is_binary(public_id) and is_integer(ticket_id) do
    with {:ok, email} <- Request.normalize_email(email) do
      scope = {:conversation, id, command.wa_id, Hash.email(email)}

      case Repo.transaction(fn ->
             challenge = fetch_challenge(public_id)

             if challenge && valid_scope?(challenge, scope) && is_nil(challenge.request_name_hash) &&
                  challenge.status == "verified" && is_nil(challenge.consumed_at) &&
                  DateTime.compare(challenge.expires_at, now) == :gt do
               bind_verified(challenge, ticket_id, now)
             else
               {:error, :invalid_or_expired}
             end
           end) do
        {:ok, result} -> result
        {:error, _} -> {:error, :invalid_or_expired}
      end
    else
      _ -> {:error, :invalid_or_expired}
    end
  end

  def bind(_public_id, _ticket_id, _now, _scope), do: {:error, :invalid_or_expired}

  defp bind_verified(
         %{ticket_issue_id: ticket_id, sales_order_id: order_id} = challenge,
         ticket_id,
         _now
       )
       when is_integer(order_id) do
    with %{sales_order_id: ^order_id, buyer_email: buyer_email} <-
           Eligibility.find_eligible_ticket(ticket_id),
         {:ok, email} <- Request.normalize_email(buyer_email),
         true <- secure_match?(challenge.request_email_hash, Hash.email(email)) do
      {:ok, :already_bound}
    else
      _ -> {:error, :invalid_or_expired}
    end
  end

  defp bind_verified(
         %{ticket_issue_id: nil, sales_order_id: nil, candidate_hash: nil} = challenge,
         ticket_id,
         now
       ) do
    with %{sales_order_id: order_id, buyer_email: buyer_email} <-
           Eligibility.find_eligible_ticket(ticket_id),
         {:ok, email} <- Request.normalize_email(buyer_email),
         true <- secure_match?(challenge.request_email_hash, Hash.email(email)),
         candidate_hash <- Hash.candidate(order_id, ticket_id),
         :ok <- RateLimit.lock!(["candidate:" <> candidate_hash]),
         :ok <- RateLimit.check_candidate(candidate_hash, now),
         {1, _} <-
           Repo.update_all(
             from(c in "sales_ticket_resend_challenges",
               where:
                 c.id == ^challenge.id and c.status == "verified" and is_nil(c.consumed_at) and
                   is_nil(c.sales_order_id) and is_nil(c.ticket_issue_id) and
                   is_nil(c.candidate_hash) and c.expires_at > ^now
             ),
             set: [
               sales_order_id: order_id,
               ticket_issue_id: ticket_id,
               candidate_hash: candidate_hash,
               updated_at: now
             ]
           ) do
      {:ok, :bound}
    else
      _ -> {:error, :invalid_or_expired}
    end
  end

  defp bind_verified(_challenge, _ticket_id, _now), do: {:error, :invalid_or_expired}

  @spec generate_code(pos_integer() | nil) :: binary()
  def generate_code(length \\ nil) do
    length = length || config(:otp_length)

    length
    |> strong_digits([])
    |> IO.iodata_to_binary()
  end

  defp strong_digits(0, digits), do: Enum.reverse(digits)

  defp strong_digits(remaining, digits) do
    digit =
      1
      |> :crypto.strong_rand_bytes()
      |> :binary.first()
      |> rem(10)
      |> Integer.to_string()

    strong_digits(remaining - 1, [digit | digits])
  end

  defp fetch_challenge(public_id) do
    Repo.one(
      from c in "sales_ticket_resend_challenges",
        where: c.public_id == ^public_id,
        lock: "FOR UPDATE",
        select:
          map(c, [
            :id,
            :public_id,
            :status,
            :sales_order_id,
            :ticket_issue_id,
            :conversation_id,
            :source_hash,
            :request_name_hash,
            :request_email_hash,
            :candidate_hash,
            :consumed_at,
            :otp_hash,
            :failed_attempt_count,
            :expires_at,
            :locked_until
          ])
    )
    |> normalize_challenge_times()
  end

  defp verify_pending(challenge, otp, now) do
    cond do
      DateTime.compare(challenge.expires_at, now) != :gt ->
        mark_expired!(challenge.id, now)
        {:error, :invalid_or_expired}

      locked?(challenge, now) ->
        {:error, :locked}

      secure_match?(challenge.otp_hash, Hash.otp(challenge.public_id, otp)) ->
        {:ok, mark_verified!(challenge.id, now)}

      true ->
        record_failed_attempt!(challenge, now)
        {:error, :invalid_or_expired}
    end
  end

  defp mark_verified!(id, now) do
    {1, _} =
      Repo.update_all(
        from(c in "sales_ticket_resend_challenges",
          where: c.id == ^id and c.status == "pending"
        ),
        set: [status: "verified", verified_at: now, updated_at: now]
      )

    get_challenge!(id)
  end

  defp mark_expired!(id, now) do
    Repo.update_all(
      from(c in "sales_ticket_resend_challenges",
        where: c.id == ^id and c.status in ["pending", "verified"]
      ),
      set: [status: "expired", updated_at: now]
    )
  end

  defp record_failed_attempt!(challenge, now) do
    failed_attempt_count = challenge.failed_attempt_count + 1

    if failed_attempt_count >= config(:max_failed_attempts) do
      locked_until = DateTime.add(now, config(:lock_seconds), :second)

      Repo.update_all(
        from(c in "sales_ticket_resend_challenges",
          where: c.id == ^challenge.id and c.status == "pending"
        ),
        set: [
          status: "blocked",
          failed_attempt_count: failed_attempt_count,
          locked_until: locked_until,
          failure_reason: "too_many_otp_failures",
          updated_at: now
        ]
      )
    else
      Repo.update_all(
        from(c in "sales_ticket_resend_challenges",
          where: c.id == ^challenge.id and c.status == "pending"
        ),
        set: [
          failed_attempt_count: failed_attempt_count,
          failure_reason: "otp_mismatch",
          updated_at: now
        ]
      )
    end
  end

  defp get_challenge!(id) do
    TicketResendChallenge
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!(actor: system_actor())
  end

  defp locked?(challenge, now) do
    not is_nil(challenge.locked_until) and DateTime.compare(challenge.locked_until, now) == :gt
  end

  defp normalize_challenge_times(nil), do: nil

  defp normalize_challenge_times(challenge) do
    challenge
    |> Map.update!(:expires_at, &to_utc_datetime/1)
    |> Map.update!(:locked_until, &to_utc_datetime/1)
  end

  defp to_utc_datetime(nil), do: nil
  defp to_utc_datetime(%DateTime{} = datetime), do: datetime

  defp to_utc_datetime(%NaiveDateTime{} = naive) do
    DateTime.from_naive!(naive, "Etc/UTC")
  end

  defp public_id do
    18
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp config(key) do
    :fastcheck
    |> Application.fetch_env!(:ticket_resend)
    |> Keyword.fetch!(key)
  end

  defp system_actor, do: %{actor_type: :system, id: "ticket_resend"}

  defp secure_match?(expected, actual) when is_binary(expected) and is_binary(actual) do
    byte_size(expected) == byte_size(actual) and Plug.Crypto.secure_compare(expected, actual)
  end

  defp secure_match?(_expected, _actual), do: false
end
