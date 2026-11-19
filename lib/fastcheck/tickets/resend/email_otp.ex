defmodule FastCheck.Tickets.Resend.EmailOtp do
  @moduledoc """
  Synchronous OTP email orchestration for ticket resend verification.
  """

  alias Ash.Query
  alias FastCheck.Mailer
  alias FastCheck.Messaging.WhatsApp.MessageCommand
  alias FastCheck.Repo
  alias FastCheck.Sales.Order
  alias FastCheck.Sales.TicketResendChallenge
  alias FastCheck.Tickets.Resend.Eligibility
  alias FastCheck.Tickets.Resend.EmailOtpRenderer
  alias FastCheck.Tickets.Resend.Hash
  alias FastCheck.Tickets.Resend.Otp
  alias FastCheck.Tickets.Resend.RateLimit
  alias FastCheck.Tickets.Resend.Request
  alias FastCheck.Tickets.Resend.Result
  alias Swoosh.Email
  import Ecto.Query

  @default_from_name "FastCheck"
  @default_from_email "no-reply@fastcheck.local"

  @type verify_error :: :invalid_or_expired | :locked | :already_verified

  @doc """
  Issues an unbound email challenge for a trusted webhook conversation.

  The caller must obtain the command through the signed and account-scoped
  ingress. Email and source rate checks and creation share advisory locks;
  indexed challenge counts remain authoritative. Delivery is synchronous and
  occurs after commit, so a delivery failure does not roll back the challenge.
  """
  def request_email_first(email, scope, opts \\ [])

  def request_email_first(email, {id, %MessageCommand{} = command}, opts) do
    now = Keyword.get(opts, :now, DateTime.utc_now() |> DateTime.truncate(:second))

    with {:ok, normalized} <- Request.normalize_email(email),
         true <- is_integer(id) and id > 0 and is_binary(command.wa_id),
         {:ok, {challenge, otp}} <- issue_email_first(normalized, id, command.wa_id, now) do
      if challenge.request_email_hash == Hash.email(normalized) do
        try do
          with {:ok, message} <- build_email(normalized, otp), do: deliver_email(message, opts)
        rescue
          _ -> :error
        end
      end

      {:ok,
       Result.new(:accepted, :otp_challenge_created, challenge_public_id: challenge.public_id)}
    else
      _ -> {:ok, Result.new(:generic_rejected, :invalid_input)}
    end
  end

  def request_email_first(_email, _scope, _opts),
    do: {:ok, Result.new(:generic_rejected, :invalid_input)}

  @doc "Verifies an email-first challenge using trusted inbound context and server time."
  def verify_email_first(public_id, submitted_otp, scope, opts \\ []) do
    Otp.verify(
      public_id,
      submitted_otp,
      Keyword.get(opts, :now, DateTime.utc_now() |> DateTime.truncate(:second)),
      scope
    )
  end

  @doc "Binds one eligible ticket after email verification, without queueing delivery."
  def bind_email_first(public_id, ticket_id, scope, opts \\ []) do
    Otp.bind(
      public_id,
      ticket_id,
      Keyword.get(opts, :now, DateTime.utc_now() |> DateTime.truncate(:second)),
      scope
    )
  end

  defp issue_email_first(email, id, wa_id, now) do
    email_hash = Hash.email(email)
    source_hash = Hash.source(%{conversation_id: id})

    Repo.transaction(fn ->
      # Stable ordering avoids deadlocks when concurrent requests share an identity.
      RateLimit.lock!(["email:" <> email_hash, "source:" <> source_hash])

      if Repo.one(
           from c in "sales_conversations",
             where: c.id == ^id and c.wa_id == ^wa_id,
             lock: "FOR SHARE",
             select: c.id
         ) == id and
           RateLimit.check_lookup(email_hash, source_hash, now) == :ok do
        case Otp.issue(
               %{conversation_id: id, source_hash: source_hash, request_email_hash: email_hash},
               now,
               return_otp?: true
             ) do
          {:ok, challenge, otp} -> {challenge, otp}
          {:error, reason} -> Repo.rollback(reason)
        end
      else
        Repo.rollback(:unavailable)
      end
    end)
  end

  @spec request_email_otp(Request.t() | map(), keyword()) :: {:ok, Result.t()}
  def request_email_otp(request, opts \\ []) do
    eligibility_opts = Keyword.put(opts, :return_otp?, true)
    {:ok, result, otp_payload} = request_otp_challenge(request, eligibility_opts)

    maybe_send_otp_email(result, otp_payload, opts)
    {:ok, result}
  end

  @spec verify_otp(binary(), binary(), keyword()) ::
          {:ok, TicketResendChallenge.t()} | {:error, verify_error()}
  def verify_otp(public_id, submitted_otp, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now() |> DateTime.truncate(:second))
    Otp.verify(public_id, submitted_otp, now)
  end

  defp maybe_send_otp_email(
         %Result{public_status: :accepted, challenge_public_id: challenge_public_id},
         %{otp: otp},
         opts
       )
       when is_binary(challenge_public_id) and is_binary(otp) do
    _ = send_otp_email(challenge_public_id, otp, opts)
    :ok
  end

  defp maybe_send_otp_email(_result, _otp_payload, _opts), do: :ok

  defp request_otp_challenge(request, opts) do
    eligibility_fun = Keyword.get(opts, :eligibility_fun, &Eligibility.request_otp_challenge/2)
    eligibility_fun.(request, opts)
  end

  defp send_otp_email(challenge_public_id, otp, opts) do
    with {:ok, recipient_email} <- load_recipient_for_challenge(challenge_public_id),
         {:ok, email} <- build_email(recipient_email, otp),
         :ok <- deliver_email(email, opts) do
      :ok
    else
      _ -> :ok
    end
  rescue
    _ -> :ok
  end

  defp load_recipient_for_challenge(challenge_public_id) when is_binary(challenge_public_id) do
    with {:ok, challenge} <- get_challenge(challenge_public_id),
         :ok <- ensure_pending(challenge),
         {:ok, sales_order_id} <- extract_sales_order_id(challenge),
         {:ok, order} <- get_order(sales_order_id),
         :ok <- ensure_order_issued(order) do
      extract_valid_email(order)
    end
  end

  defp build_email(recipient_email, otp) do
    ttl_minutes = otp_ttl_minutes()

    email =
      Email.new()
      |> Email.from(otp_email_sender())
      |> Email.to(recipient_email)
      |> Email.subject(EmailOtpRenderer.subject())
      |> Email.text_body(EmailOtpRenderer.text_body(otp, ttl_minutes))
      |> Email.html_body(EmailOtpRenderer.html_body(otp, ttl_minutes))

    {:ok, email}
  end

  defp deliver_email(email, opts) do
    deliver_fun = Keyword.get(opts, :deliver_fun, &Mailer.deliver/1)

    case deliver_fun.(email) do
      {:ok, _response} -> :ok
      {:error, _reason} -> :error
      _other -> :error
    end
  end

  defp get_challenge(public_id) do
    TicketResendChallenge
    |> Query.for_read(:get_by_public_id, %{public_id: public_id})
    |> Ash.read_one(actor: system_actor())
    |> case do
      {:ok, %TicketResendChallenge{} = challenge} -> {:ok, challenge}
      {:ok, nil} -> {:error, :invalid_or_expired}
      {:error, _reason} -> {:error, :invalid_or_expired}
    end
  end

  defp get_order(order_id) when is_integer(order_id) do
    Order
    |> Query.for_read(:get_by_id, %{id: order_id})
    |> Ash.read_one(actor: system_actor())
    |> case do
      {:ok, %Order{} = order} -> {:ok, order}
      {:ok, nil} -> :error
      {:error, _reason} -> :error
    end
  end

  defp ensure_pending(%TicketResendChallenge{status: "pending"}), do: :ok
  defp ensure_pending(_challenge), do: :error

  defp extract_sales_order_id(%TicketResendChallenge{sales_order_id: sales_order_id})
       when is_integer(sales_order_id) do
    {:ok, sales_order_id}
  end

  defp extract_sales_order_id(_challenge), do: :error

  defp ensure_order_issued(%Order{status: "ticket_issued"}), do: :ok
  defp ensure_order_issued(_order), do: :error

  defp extract_valid_email(%Order{buyer_email: email}) when is_binary(email) do
    case Request.normalize_email(email) do
      {:ok, normalized_email} -> {:ok, normalized_email}
      {:error, :invalid_email} -> :error
    end
  end

  defp extract_valid_email(_order), do: :error

  defp otp_ttl_minutes do
    ttl_seconds =
      ticket_resend_config()
      |> Keyword.fetch!(:otp_ttl_seconds)

    max(div(ttl_seconds, 60), 1)
  end

  defp otp_email_sender do
    config = ticket_resend_config()
    from_name = Keyword.get(config, :otp_email_from_name, @default_from_name)
    from_email = Keyword.get(config, :otp_email_from_email, @default_from_email)
    {from_name, from_email}
  end

  defp ticket_resend_config do
    Application.fetch_env!(:fastcheck, :ticket_resend)
  end

  defp system_actor, do: %{actor_type: :system, id: "ticket_resend"}
end
