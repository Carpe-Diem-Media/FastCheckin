defmodule FastCheck.Support.SupportMessage do
  @moduledoc """
  Encrypted canonical transcript entry for one support case.

  Phase 1.1 provides the storage skeleton only; acceptance and identity guards
  are introduced by later authorized phases.
  """

  use Ash.Resource,
    domain: FastCheck.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("support_messages")
    repo(FastCheck.Repo)
  end

  actions do
    defaults([])
  end

  attributes do
    integer_primary_key(:id)

    attribute :sequence, :integer do
      allow_nil?(false)
    end

    attribute :direction, :string do
      allow_nil?(false)
    end

    attribute(:sender_operator_id, :string, sensitive?: true)
    attribute(:client_submission_id, :string, sensitive?: true)
    attribute(:provider_account_key, :string, sensitive?: true)
    attribute(:provider_message_id, :string, sensitive?: true)

    attribute :body_ciphertext, :string do
      allow_nil?(false)
      sensitive?(true)
    end

    attribute :body_key_version, :string do
      allow_nil?(false)
      sensitive?(true)
    end

    attribute :accepted_at, :utc_datetime do
      allow_nil?(false)
    end

    attribute(:provider_accepted_at, :utc_datetime)
    attribute(:delivery_confirmed_at, :utc_datetime)
    attribute(:failure_class, :string)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :support_case, FastCheck.Support.SupportCase do
      source_attribute(:support_case_id)
      attribute_type(:integer)
      allow_nil?(false)
    end

    has_many :operations, FastCheck.Support.ExternalCreateOperation do
      destination_attribute(:support_message_id)
    end
  end
end
