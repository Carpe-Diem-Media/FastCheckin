defmodule FastCheck.Support.SupportCaseEvent do
  @moduledoc """
  Append-only audit record for a support case.

  Lifecycle events are inserted only through a private create action invoked by
  their parent SupportCase transaction. There are no update, destroy, or read
  actions.
  """

  use Ash.Resource,
    domain: FastCheck.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("support_case_events")
    repo(FastCheck.Repo)

    identity_index_names(
      unique_customer_exit_wamid: "support_case_events_customer_exit_wamid_uidx"
    )

    check_constraints do
      check_constraint(
        [:provider_account_key, :provider_message_id],
        "support_case_events_customer_exit_identity_required",
        message: "must be present for customer exit events"
      )
    end

    identity_wheres_to_sql(unique_customer_exit_wamid: "event_type = 'customer_exit'")
  end

  actions do
    defaults([])

    create :record_lifecycle_event do
      public?(false)
      transaction?(true)

      accept([
        :support_case_id,
        :sequence,
        :event_type,
        :actor_type,
        :actor_id,
        :provider_account_key,
        :provider_message_id,
        :case_version,
        :metadata
      ])
    end
  end

  policies do
    policy action(:record_lifecycle_event) do
      access_type(:strict)
      authorize_if({FastCheck.Support.SupportCase.Checks, kind: :intake})
      authorize_if({FastCheck.Support.SupportCase.Checks, kind: :operator})
      authorize_if({FastCheck.Support.SupportCase.Checks, kind: :customer_exit})
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :sequence, :integer do
      allow_nil?(false)
    end

    attribute :event_type, :string do
      allow_nil?(false)
    end

    attribute :actor_type, :string do
      allow_nil?(false)
    end

    attribute :actor_id, :string do
      allow_nil?(false)
      sensitive?(true)
    end

    attribute(:provider_account_key, :string, sensitive?: true)
    attribute(:provider_message_id, :string, sensitive?: true)

    attribute :case_version, :integer do
      allow_nil?(false)
    end

    attribute :metadata, :map do
      allow_nil?(false)
      default(%{})
      sensitive?(true)
    end

    create_timestamp(:inserted_at)
  end

  relationships do
    belongs_to :support_case, FastCheck.Support.SupportCase do
      source_attribute(:support_case_id)
      attribute_type(:integer)
      allow_nil?(false)
    end

    belongs_to :support_message, FastCheck.Support.SupportMessage do
      source_attribute(:support_message_id)
      attribute_type(:integer)
    end

    belongs_to :external_create_operation, FastCheck.Support.ExternalCreateOperation do
      source_attribute(:external_create_operation_id)
      attribute_type(:integer)
    end

    belongs_to :conversation_closure, FastCheck.Support.ConversationClosure do
      source_attribute(:conversation_closure_id)
      attribute_type(:integer)
    end
  end

  identities do
    identity :unique_customer_exit_wamid, [:provider_account_key, :provider_message_id] do
      where(expr(event_type == "customer_exit"))
    end
  end
end
