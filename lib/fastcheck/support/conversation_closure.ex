defmodule FastCheck.Support.ConversationClosure do
  @moduledoc """
  Durable closure-fence attempt for one support case generation.

  Phase 1.1 records the schema only. Resolution remains unavailable until the
  complete transactional close fence is implemented in Phase 5.
  """

  use Ash.Resource,
    domain: FastCheck.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("conversation_closures")
    repo(FastCheck.Repo)
  end

  actions do
    defaults([])
  end

  attributes do
    integer_primary_key(:id)

    attribute :closure_epoch, :integer do
      allow_nil?(false)
    end

    attribute :state, :string do
      allow_nil?(false)
    end

    attribute :case_version, :integer do
      allow_nil?(false)
    end

    attribute(:fence_sequence, :integer)
    attribute(:actor_id, :string, sensitive?: true)

    attribute :requested_at, :utc_datetime do
      allow_nil?(false)
    end

    attribute(:resolved_at, :utc_datetime)
    attribute(:recovery_reason, :string)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :support_case, FastCheck.Support.SupportCase do
      source_attribute(:support_case_id)
      attribute_type(:integer)
      allow_nil?(false)
    end
  end
end
