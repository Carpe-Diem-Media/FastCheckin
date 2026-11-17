defmodule FastCheck.Support.SupportCase.Checks do
  @moduledoc false

  use Ash.Policy.SimpleCheck

  alias FastCheck.Messaging.WhatsApp.Config
  alias FastCheck.Operations.GlobalAccess
  alias Plug.Conn

  @actor_private_key :fastcheck_verified_support_actor

  def describe(opts), do: "verified support actor: #{Keyword.fetch!(opts, :kind)}"

  def match?(%Conn{} = conn, _context, opts) do
    case Keyword.get(opts, :kind) do
      :operator -> operator_username(conn) != nil
      :intake -> system_identity(conn, :intake) != nil
      :customer_exit -> system_identity(conn, :customer_exit) != nil
      _ -> false
    end
  end

  def match?(_, _context, _opts), do: false

  def operator_username(%Conn{} = conn) do
    username = Conn.get_session(conn, :dashboard_username)
    current_user = Map.get(conn.assigns, :current_user)

    with true <- is_binary(username),
         true <- username != "",
         true <- username == String.trim(username),
         true <- is_map(current_user),
         true <- Map.get(current_user, :username) == username,
         true <- GlobalAccess.authorized_identity?(conn) do
      username
    else
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  def system_identity(%Conn{} = conn, kind) when kind in [:intake, :customer_exit] do
    context = Map.get(conn.private, @actor_private_key)
    configured_account = Config.get().business_account_id

    with %{kind: ^kind, wa_id: wa_id, provider_account_key: account_key} = context
         when is_binary(wa_id) and wa_id != "" <- context,
         true <- wa_id == String.trim(wa_id),
         true <- is_binary(configured_account) and configured_account != "",
         true <- account_key == configured_account,
         true <- verified_message?(kind, Map.get(context, :provider_message_id)) do
      context
    else
      _ -> nil
    end
  end

  def system_identity(_, _kind), do: nil

  defp verified_message?(:intake, _provider_message_id), do: true

  defp verified_message?(:customer_exit, provider_message_id) do
    is_binary(provider_message_id) and provider_message_id != "" and
      provider_message_id == String.trim(provider_message_id)
  end
end

defmodule FastCheck.Support.SupportCase do
  @moduledoc """
  Durable support lifecycle for one generation of a Sales conversation.

  Customer intake authority is supplied only through the server-private
  `:fastcheck_verified_support_actor` context after a trusted adapter verifies
  the provider identity. This resource does not enable or register intake
  integration itself.
  """

  use Ash.Resource,
    domain: FastCheck.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Ash.Changeset
  alias FastCheck.Messaging.WhatsApp.Config
  alias FastCheck.Repo
  alias FastCheck.Support.SupportCase.Checks
  alias FastCheck.Support.SupportCaseEvent

  postgres do
    table("support_cases")
    repo(FastCheck.Repo)
  end

  actions do
    defaults([])

    create :create_waiting do
      public?(false)
      transaction?(true)
      accept([])

      argument :conversation_id, :integer do
        allow_nil?(false)
      end

      change(&prepare_intake/2)
    end

    read :get_by_id do
      public?(false)
      get?(true)

      argument :id, :integer do
        allow_nil?(false)
      end

      filter(expr(id == ^arg(:id)))
    end

    update :claim do
      public?(false)
      require_atomic?(false)
      transaction?(true)
      accept([])
      argument(:expected_lock_version, :integer, allow_nil?: false)

      change(&prepare_transition(&1, &2, :claim))
      change(optimistic_lock(:lock_version))
    end

    update :release do
      public?(false)
      require_atomic?(false)
      transaction?(true)
      accept([])
      argument(:expected_lock_version, :integer, allow_nil?: false)

      change(&prepare_transition(&1, &2, :release))
      change(optimistic_lock(:lock_version))
    end

    update :customer_cancel do
      public?(false)
      require_atomic?(false)
      transaction?(true)
      accept([])
      argument(:expected_lock_version, :integer, allow_nil?: false)

      change(&prepare_transition(&1, &2, :customer_cancel))
      change(optimistic_lock(:lock_version))
    end
  end

  policies do
    policy action(:create_waiting) do
      access_type(:strict)
      authorize_if({Checks, kind: :intake})
    end

    policy action(:get_by_id) do
      access_type(:strict)
      authorize_if({Checks, kind: :operator})
    end

    policy action(:claim) do
      access_type(:strict)
      authorize_if({Checks, kind: :operator})
    end

    policy action(:release) do
      access_type(:strict)
      authorize_if({Checks, kind: :operator})
    end

    policy action(:customer_cancel) do
      access_type(:strict)
      authorize_if({Checks, kind: :customer_exit})
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :public_id, :uuid do
      allow_nil?(false)
    end

    attribute :generation, :integer do
      allow_nil?(false)
      default(1)
    end

    attribute :state, :string do
      allow_nil?(false)
      default("waiting")
    end

    attribute :reason_code, :string do
      constraints(max_length: 64, length_count: :codepoints)
    end

    attribute(:assigned_operator_id, :string, sensitive?: true)

    attribute :requested_at, :utc_datetime do
      allow_nil?(false)
    end

    attribute(:claimed_at, :utc_datetime)
    attribute(:resolved_at, :utc_datetime)
    attribute(:cancelled_at, :utc_datetime)

    attribute :next_message_sequence, :integer do
      allow_nil?(false)
      default(1)
    end

    attribute :lock_version, :integer do
      allow_nil?(false)
      default(1)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :conversation, FastCheck.Sales.Conversation do
      source_attribute(:conversation_id)
      attribute_type(:integer)
      allow_nil?(false)
    end

    has_many :messages, FastCheck.Support.SupportMessage do
      destination_attribute(:support_case_id)
    end

    has_many :operations, FastCheck.Support.ExternalCreateOperation do
      destination_attribute(:support_case_id)
    end

    has_many :closures, FastCheck.Support.ConversationClosure do
      destination_attribute(:support_case_id)
    end

    has_many :events, FastCheck.Support.SupportCaseEvent do
      destination_attribute(:support_case_id)
    end
  end

  identities do
    identity(:unique_public_id, [:public_id])
  end

  defp prepare_intake(changeset, %{actor: actor}) do
    Changeset.before_action(changeset, fn changeset ->
      case lock_intake_conversation(changeset, actor) do
        {:ok, conversation_id, _account_key} ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          changeset
          |> Changeset.force_change_attribute(:conversation_id, conversation_id)
          |> Changeset.force_change_attribute(:public_id, Ecto.UUID.generate())
          |> Changeset.force_change_attribute(:generation, 1)
          |> Changeset.force_change_attribute(:state, "waiting")
          |> Changeset.force_change_attribute(:assigned_operator_id, nil)
          |> Changeset.force_change_attribute(:requested_at, now)
          |> Changeset.force_change_attribute(:claimed_at, nil)
          |> Changeset.force_change_attribute(:resolved_at, nil)
          |> Changeset.force_change_attribute(:cancelled_at, nil)
          |> Changeset.force_change_attribute(:next_message_sequence, 1)
          |> Changeset.force_change_attribute(:lock_version, 1)

        {:error, reason} ->
          add_lifecycle_error(changeset, reason)
      end
    end)
    |> Changeset.after_action(fn _changeset, record ->
      append_event(record, actor, :intake_created, nil, "waiting")
    end)
  end

  defp prepare_transition(changeset, %{actor: actor}, action) do
    from_state = Changeset.get_data(changeset, :state)

    Changeset.before_action(changeset, fn changeset ->
      case lock_and_validate_transition(changeset, actor, action) do
        {:ok, account_key} ->
          changeset
          |> Changeset.put_context(:support_case_account_key, account_key)
          |> apply_transition(actor, action)

        {:error, reason} ->
          add_lifecycle_error(changeset, reason)
      end
    end)
    |> Changeset.after_action(fn changeset, record ->
      event_type = transition_event(action)
      account_key = changeset.context[:support_case_account_key]
      append_event(record, actor, event_type, from_state, record.state, account_key)
    end)
  end

  defp lock_intake_conversation(changeset, actor) do
    conversation_id = Changeset.get_argument(changeset, :conversation_id)

    with {:ok, identity} <- verified_system_actor(actor, :intake),
         {:ok, wa_id} <- conversation_wa_id(conversation_id),
         :ok <- advisory_lock(wa_id),
         {:ok, conversation} <- lock_conversation(conversation_id),
         true <- conversation.wa_id == wa_id,
         true <- identity.wa_id == conversation.wa_id,
         :ok <- no_prior_case(conversation_id) do
      {:ok, conversation_id, identity.provider_account_key}
    else
      false -> {:error, :intake_identity_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  defp lock_and_validate_transition(changeset, actor, action) do
    conversation_id = Changeset.get_data(changeset, :conversation_id)
    expected_version = Changeset.get_argument(changeset, :expected_lock_version)
    data_version = Changeset.get_data(changeset, :lock_version)

    with {:ok, identity} <- transition_identity(actor, action),
         {:ok, wa_id} <- conversation_wa_id(conversation_id),
         :ok <- advisory_lock(wa_id),
         {:ok, conversation} <- lock_conversation(conversation_id),
         true <- conversation.wa_id == wa_id,
         :ok <- verify_conversation_identity(identity, conversation, action),
         {:ok, support_case} <- lock_case(Changeset.get_data(changeset, :id), conversation_id),
         :ok <- verify_versions(expected_version, data_version, support_case.lock_version),
         {:ok, account_key} <- verify_case_account(support_case.id, identity),
         :ok <- validate_state_and_actor(support_case, identity, action) do
      {:ok, account_key}
    else
      false -> {:error, :conversation_identity_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  defp transition_identity(actor, action) when action in [:claim, :release] do
    case Checks.operator_username(actor) do
      username when is_binary(username) -> {:ok, %{kind: :operator, username: username}}
      _ -> {:error, :operator_authority_revoked}
    end
  end

  defp transition_identity(actor, :customer_cancel) do
    case verified_system_actor(actor, :customer_exit) do
      {:ok, identity} -> {:ok, Map.put(identity, :kind, :customer_exit)}
      error -> error
    end
  end

  defp verify_conversation_identity(%{kind: :customer_exit, wa_id: wa_id}, conversation, _action),
    do: if(wa_id == conversation.wa_id, do: :ok, else: {:error, :customer_identity_mismatch})

  defp verify_conversation_identity(_identity, _conversation, _action), do: :ok

  defp verify_versions(expected, data_version, actual)
       when expected == data_version and expected == actual,
       do: :ok

  defp verify_versions(_expected, _data_version, _actual), do: {:error, :stale_case_version}

  defp verify_case_account(case_id, identity) do
    with {:ok, account_key} <- intake_account_key(case_id),
         configured_account when is_binary(configured_account) <- Config.get().business_account_id,
         true <- account_key == configured_account,
         true <- identity_account(identity) == account_key do
      {:ok, account_key}
    else
      _ -> {:error, :case_account_mismatch}
    end
  end

  defp validate_state_and_actor(support_case, %{kind: :operator, username: _username}, :claim) do
    if support_case.state == "waiting" and is_nil(support_case.assigned_operator_id),
      do: :ok,
      else: {:error, :case_not_waiting}
  end

  defp validate_state_and_actor(support_case, %{kind: :operator, username: username}, :release) do
    if support_case.state == "claimed" and support_case.assigned_operator_id == username,
      do: :ok,
      else: {:error, :current_assignee_required}
  end

  defp validate_state_and_actor(support_case, %{kind: :customer_exit}, :customer_cancel) do
    if support_case.state in ["waiting", "claimed"],
      do: :ok,
      else: {:error, :case_not_cancellable}
  end

  defp apply_transition(changeset, actor, :claim) do
    username = Checks.operator_username(actor)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset
    |> Changeset.force_change_attribute(:state, "claimed")
    |> Changeset.force_change_attribute(:assigned_operator_id, username)
    |> Changeset.force_change_attribute(:claimed_at, now)
  end

  defp apply_transition(changeset, _actor, :release) do
    changeset
    |> Changeset.force_change_attribute(:state, "waiting")
    |> Changeset.force_change_attribute(:assigned_operator_id, nil)
    |> Changeset.force_change_attribute(:claimed_at, nil)
  end

  defp apply_transition(changeset, _actor, :customer_cancel) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Changeset.force_change_attribute(changeset, :state, "cancelled")
    |> Changeset.force_change_attribute(:cancelled_at, now)
  end

  defp append_event(record, actor, event_type, from_state, to_state, account_key \\ nil) do
    sequence = next_event_sequence(record.id)

    with {:ok, identity} <- event_identity(actor, event_type, record, account_key) do
      attrs = %{
        support_case_id: record.id,
        sequence: sequence,
        event_type: Atom.to_string(event_type),
        actor_type: identity.actor_type,
        actor_id: identity.actor_id,
        provider_account_key: identity.provider_account_key,
        provider_message_id: identity.provider_message_id,
        case_version: record.lock_version,
        metadata: %{from_state: from_state, to_state: to_state}
      }

      SupportCaseEvent
      |> Changeset.for_create(:record_lifecycle_event, attrs, actor: actor)
      |> Ash.create(authorize?: true)
      |> case do
        {:ok, _event} -> {:ok, record}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp event_identity(actor, :intake_created, _record, _account_key) do
    identity = Checks.system_identity(actor, :intake)

    if identity do
      {:ok,
       %{
         actor_type: "system",
         actor_id: "support_intake",
         provider_account_key: identity.provider_account_key,
         provider_message_id: nil
       }}
    else
      {:error, :verified_intake_identity_required}
    end
  end

  defp event_identity(actor, event_type, _record, account_key)
       when event_type in [:operator_claimed, :operator_released] do
    case Checks.operator_username(actor) do
      username when is_binary(username) ->
        {:ok,
         %{
           actor_type: "operator",
           actor_id: username,
           provider_account_key: account_key,
           provider_message_id: nil
         }}

      _ ->
        {:error, :operator_authority_revoked}
    end
  end

  defp event_identity(actor, :customer_exit, record, _account_key) do
    identity = Checks.system_identity(actor, :customer_exit)

    if identity do
      {:ok,
       %{
         actor_type: "customer",
         actor_id: Integer.to_string(record.conversation_id),
         provider_account_key: identity.provider_account_key,
         provider_message_id: identity.provider_message_id
       }}
    else
      {:error, :verified_customer_identity_required}
    end
  end

  defp next_event_sequence(case_id) do
    case Repo.query!(
           "SELECT COALESCE(MAX(sequence), 0) + 1 FROM support_case_events WHERE support_case_id = $1",
           [case_id]
         ).rows do
      [[sequence]] -> sequence
    end
  end

  defp transition_event(:claim), do: :operator_claimed
  defp transition_event(:release), do: :operator_released
  defp transition_event(:customer_cancel), do: :customer_exit

  defp verified_system_actor(actor, kind) do
    case Checks.system_identity(actor, kind) do
      nil -> {:error, :verified_system_identity_required}
      identity -> {:ok, identity}
    end
  end

  defp identity_account(%{kind: :operator}), do: Config.get().business_account_id
  defp identity_account(%{provider_account_key: account_key}), do: account_key
  defp identity_account(_identity), do: nil

  defp conversation_wa_id(conversation_id) do
    case Repo.query!("SELECT wa_id FROM sales_conversations WHERE id = $1", [conversation_id]).rows do
      [[wa_id]] -> {:ok, wa_id}
      [] -> {:error, :conversation_not_found}
    end
  end

  defp lock_conversation(conversation_id) do
    case Repo.query!(
           "SELECT wa_id FROM sales_conversations WHERE id = $1 FOR UPDATE",
           [conversation_id]
         ).rows do
      [[wa_id]] -> {:ok, %{wa_id: wa_id}}
      [] -> {:error, :conversation_not_found}
    end
  end

  defp lock_case(case_id, conversation_id) do
    case Repo.query!(
           """
           SELECT id, conversation_id, state, assigned_operator_id, lock_version
           FROM support_cases
           WHERE id = $1 AND conversation_id = $2
           FOR UPDATE
           """,
           [case_id, conversation_id]
         ).rows do
      [[id, conversation_id, state, assigned_operator_id, lock_version]] ->
        {:ok,
         %{
           id: id,
           conversation_id: conversation_id,
           state: state,
           assigned_operator_id: assigned_operator_id,
           lock_version: lock_version
         }}

      [] ->
        {:error, :case_not_found}
    end
  end

  defp intake_account_key(case_id) do
    case Repo.query!(
           """
           SELECT provider_account_key
           FROM support_case_events
           WHERE support_case_id = $1 AND sequence = 1 AND event_type = 'intake_created'
           """,
           [case_id]
         ).rows do
      [[account_key]] when is_binary(account_key) -> {:ok, account_key}
      _ -> {:error, :intake_identity_missing}
    end
  end

  defp no_prior_case(conversation_id) do
    case Repo.query!(
           "SELECT id FROM support_cases WHERE conversation_id = $1 FOR UPDATE",
           [conversation_id]
         ).rows do
      [] -> :ok
      _ -> {:error, :case_generation_exists}
    end
  end

  defp advisory_lock(wa_id) do
    lock_id =
      :crypto.hash(:sha256, wa_id)
      |> binary_part(0, 8)
      |> :binary.decode_unsigned()
      |> rem(9_223_372_036_854_775_807)

    Repo.query!("SELECT pg_advisory_xact_lock($1)", [lock_id])
    :ok
  end

  defp add_lifecycle_error(changeset, reason) do
    Changeset.add_error(changeset,
      field: :state,
      message: "support case lifecycle guard rejected operation (#{reason})"
    )
  end
end
