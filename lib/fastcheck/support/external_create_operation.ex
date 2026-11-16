defmodule FastCheck.Support.ExternalCreateOperation do
  @moduledoc """
  Durable lifecycle record for one logical external support-message operation.

  No dispatcher or mutation action is exposed in this Phase 1.1 skeleton.
  """

  use Ash.Resource,
    domain: FastCheck.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("external_create_operations")
    repo(FastCheck.Repo)
  end

  actions do
    defaults([])
  end

  attributes do
    integer_primary_key(:id)

    attribute :operation_id, :uuid do
      allow_nil?(false)
      sensitive?(true)
    end

    attribute :provider, :string do
      allow_nil?(false)
    end

    attribute :operation_kind, :string do
      allow_nil?(false)
    end

    attribute(:provider_account_key, :string, sensitive?: true)
    attribute(:source_key, :string, sensitive?: true)

    attribute :state, :string do
      allow_nil?(false)
      default("queued")
    end

    attribute :attempt_number, :integer do
      allow_nil?(false)
      default(0)
    end

    attribute :fencing_version, :integer do
      allow_nil?(false)
      default(0)
    end

    attribute :lock_version, :integer do
      allow_nil?(false)
      default(1)
    end

    attribute(:next_attempt_at, :utc_datetime)
    attribute(:dispatch_authorized_at, :utc_datetime)
    attribute(:dispatch_started_at, :utc_datetime)
    attribute(:response_received_at, :utc_datetime)
    attribute(:provider_message_id, :string, sensitive?: true)

    attribute :response_class, :string do
      constraints(max_length: 64, length_count: :codepoints)
    end

    attribute :failure_class, :string do
      constraints(max_length: 64, length_count: :codepoints)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
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
      allow_nil?(false)
    end
  end
end
