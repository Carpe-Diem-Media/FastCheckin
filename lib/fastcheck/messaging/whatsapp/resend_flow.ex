defmodule FastCheck.Messaging.WhatsApp.ResendFlow do
  @moduledoc """
  WhatsApp resend identity collection orchestration for VS-24D-C.
  """

  alias FastCheck.Messaging.WhatsApp.MessageCommand
  alias FastCheck.Repo
  alias FastCheck.Sales.Conversation
  alias FastCheck.Tickets.Resend.Eligibility
  alias FastCheck.Tickets.Resend.EmailOtp
  alias FastCheck.Tickets.Resend.Otp
  alias FastCheck.Tickets.Resend.Request
  alias FastCheck.Tickets.Resend.Result

  @spec normalize_name(term()) :: {:ok, String.t()} | {:error, :invalid_name}
  defdelegate normalize_name(name), to: Request

  @spec normalize_email(term()) :: {:ok, String.t()} | {:error, :invalid_email}
  defdelegate normalize_email(email), to: Request

  @spec request_email_otp(MessageCommand.t(), Conversation.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def request_email_otp(%MessageCommand{} = command, %Conversation{} = conversation, opts \\ []) do
    state_data = Keyword.get(opts, :state_data, state_data(conversation))
    email_otp_fun = Keyword.get(opts, :email_otp_fun, &EmailOtp.request_email_first/3)
    email = Map.get(state_data, "resend_email")
    request = {conversation.id, command}

    with {:ok, %Result{} = result} <- email_otp_fun.(email, request, []) do
      {:ok, result_updates(result, command)}
    end
  end

  @spec verify_email_otp(MessageCommand.t(), Conversation.t(), keyword()) ::
          {:ok, :verified, map()}
          | {:error, :invalid_or_expired | :locked | :already_verified}
  def verify_email_otp(%MessageCommand{} = command, %Conversation{} = conversation, opts \\ []) do
    state_data = Keyword.get(opts, :state_data, state_data(conversation))
    verify_otp_fun = Keyword.get(opts, :verify_otp_fun, &EmailOtp.verify_email_first/4)

    with {:ok, public_id} <- challenge_public_id(state_data),
         {:ok, otp} <- submitted_otp(command) do
      scope = {conversation.id, command, state_data["resend_email"]}

      case with_challenge_lock(public_id, fn -> verify_otp_fun.(public_id, otp, scope, []) end) do
        {:ok, challenge} ->
          {:ok, :verified, verification_updates(command, challenge)}

        {:error, :already_verified} ->
          case with_challenge_lock(public_id, fn ->
                 Otp.recover_verified(public_id, otp, scope)
               end) do
            {:ok, challenge} -> {:ok, :verified, verification_updates(command, challenge)}
            _ -> {:error, :already_verified}
          end

        {:error, :locked} ->
          {:error, :locked}

        _ ->
          {:error, :invalid_or_expired}
      end
    else
      _ -> {:error, :invalid_or_expired}
    end
  end

  def expire(command, conversation) do
    data = state_data(conversation)

    case challenge_public_id(data) do
      {:ok, public_id} -> Otp.expire(public_id, {conversation.id, command, data["resend_email"]})
      _ -> {:ok, :ok}
    end
  end

  def candidates(%Conversation{} = conversation) do
    data = state_data(conversation)

    if Eligibility.canonical_coverage_complete?() do
      Eligibility.candidates_for_email(data["resend_email"], conversation.phone_e164)
    else
      []
    end
  end

  def bind(command, conversation, ticket_id) do
    data = state_data(conversation)

    with {:ok, public_id} <- challenge_public_id(data) do
      with_challenge_lock(public_id, fn ->
        EmailOtp.bind_email_first(
          public_id,
          ticket_id,
          {conversation.id, command, data["resend_email"]}
        )
      end)
    end
  end

  # Acquire the challenge before obtaining server time inside the reviewed OTP
  # APIs. A wait for a concurrent operation must not extend its lifetime.
  defp with_challenge_lock(public_id, operation) do
    case Repo.transaction(fn ->
           Repo.query!(
             "SELECT id FROM sales_ticket_resend_challenges WHERE public_id = $1 FOR UPDATE",
             [public_id],
             log: false
           )

           operation.()
         end) do
      {:ok, result} -> result
      {:error, _} -> {:error, :invalid_or_expired}
    end
  end

  defp result_updates(%Result{} = result, %MessageCommand{} = command) do
    %{
      "resend_requested_at" => DateTime.to_iso8601(command.received_at),
      "resend_email_otp_result_status" => Atom.to_string(result.public_status),
      "resend_correlation_id" => command.correlation_id
    }
    |> maybe_put_challenge_public_id(result)
  end

  defp maybe_put_challenge_public_id(updates, %Result{
         public_status: :accepted,
         challenge_public_id: challenge_public_id
       })
       when is_binary(challenge_public_id) and challenge_public_id != "" do
    Map.put(updates, "resend_challenge_public_id", challenge_public_id)
  end

  defp maybe_put_challenge_public_id(updates, _result), do: updates

  defp challenge_public_id(state_data) do
    case Map.get(state_data, "resend_challenge_public_id") do
      challenge_public_id when is_binary(challenge_public_id) ->
        challenge_public_id
        |> String.trim()
        |> case do
          "" -> {:error, :invalid_or_expired}
          value -> {:ok, value}
        end

      _other ->
        {:error, :invalid_or_expired}
    end
  end

  defp submitted_otp(%MessageCommand{text_body: text_body}) do
    submitted_otp =
      (text_body || "")
      |> to_string()
      |> String.trim()

    if Regex.match?(~r/^\d+$/, submitted_otp) do
      {:ok, submitted_otp}
    else
      {:error, :invalid_or_expired}
    end
  end

  defp verification_updates(%MessageCommand{} = command, challenge) do
    updates = %{
      "resend_otp_verified_at" => DateTime.to_iso8601(command.received_at),
      "resend_otp_verification_status" => "verified"
    }

    updates =
      case challenge do
        %{expires_at: %DateTime{} = expires_at} ->
          Map.put(updates, "resend_challenge_expires_at", DateTime.to_iso8601(expires_at))

        _ ->
          updates
      end

    case challenge do
      %{ticket_issue_id: ticket} when is_integer(ticket) ->
        Map.put(updates, "resend_bound_ticket_id", ticket)

      _ ->
        updates
    end
  end

  defp state_data(%Conversation{state_data: data}) when is_map(data), do: data
  defp state_data(_conversation), do: %{}
end
