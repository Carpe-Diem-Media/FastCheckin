defmodule FastCheck.Support.SupportCaseEvent do
  @moduledoc """
  Append-only audit record for a support case.

  This schema exposes no actions; event creation is added only alongside the
  guarded domain transitions that own each event.
  """

  use Ash.Resource,
    domain: FastCheck.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("support_case_events")
    repo(FastCheck.Repo)

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
