defmodule FastCheck.Support.SupportCase do
  @moduledoc """
  Durable support lifecycle for one generation of a Sales conversation.

  This Phase 1.1 resource exposes no actions. Guarded lifecycle actions are
  added in the separately scoped Phase 1.3 tickets.
  """

  use Ash.Resource,
    domain: FastCheck.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("support_cases")
    repo(FastCheck.Repo)
  end

  actions do
    defaults([])
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
end
