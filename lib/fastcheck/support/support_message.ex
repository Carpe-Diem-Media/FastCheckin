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

    check_constraints do
      check_constraint(
        [:provider_account_key, :client_submission_id],
        "support_messages_operator_identity_required",
        message: "must be present for operator messages"
      )

      check_constraint(
        [:provider_account_key, :provider_message_id],
        "support_messages_customer_identity_required",
        message: "must be present for customer messages"
      )
    end

    identity_wheres_to_sql(
      unique_operator_submission: "direction = 'operator'",
      unique_customer_wamid: "direction = 'customer'"
    )
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

  identities do
    identity :unique_operator_submission, [:provider_account_key, :client_submission_id] do
      where(expr(direction == "operator"))
    end

    identity :unique_customer_wamid, [:provider_account_key, :provider_message_id] do
      where(expr(direction == "customer"))
    end
  end
end
