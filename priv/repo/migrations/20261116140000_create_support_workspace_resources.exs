defmodule FastCheck.Repo.Migrations.CreateSupportWorkspaceResources do
  use Ecto.Migration

  @case_states ["waiting", "claimed", "resolved", "cancelled"]
  @operation_states [
    "queued",
    "dispatching",
    "provider_accepted",
    "failed_retryable",
    "failed_permanent",
    "suppressed_before_dispatch",
    "retry_suppressed",
    "outcome_unknown",
    "reconciling",
    "needs_review"
  ]
  @closure_states [
    "requested",
    "fenced",
    "reconciling",
    "resolved",
    "recovery_required",
    "aborted"
  ]

  def change do
    create table(:support_cases) do
      add(:conversation_id, references(:sales_conversations, on_delete: :restrict), null: false)
      add(:generation, :integer, null: false, default: 1)
      add(:state, :string, null: false, default: "waiting")
      add(:assigned_operator_id, :string)
      add(:requested_at, :utc_datetime, null: false)
      add(:claimed_at, :utc_datetime)
      add(:next_message_sequence, :bigint, null: false, default: 1)
      add(:lock_version, :bigint, null: false, default: 1)

      timestamps(type: :utc_datetime)
    end

    create table(:support_messages) do
      add(:support_case_id, references(:support_cases, on_delete: :restrict), null: false)
      add(:sequence, :bigint, null: false)
      add(:direction, :string, null: false)
      add(:sender_operator_id, :string)
      add(:client_submission_id, :string)
      add(:provider_account_key, :string)
      add(:provider_message_id, :string)
      add(:body_ciphertext, :text, null: false)
      add(:body_key_version, :string, null: false)
      add(:accepted_at, :utc_datetime, null: false)
      add(:provider_accepted_at, :utc_datetime)
      add(:delivery_confirmed_at, :utc_datetime)
      add(:failure_class, :string)

      timestamps(type: :utc_datetime)
    end

    create(
      unique_index(:support_messages, [:id, :support_case_id],
        name: :support_messages_id_case_uidx
      )
    )

    create table(:external_create_operations) do
      add(:operation_id, :uuid, null: false)
      add(:support_case_id, references(:support_cases, on_delete: :restrict), null: false)

      add(
        :support_message_id,
        references(:support_messages,
          with: [support_case_id: :support_case_id],
          on_delete: :restrict
        ),
        null: false
      )

      add(:provider, :string, null: false)
      add(:operation_kind, :string, null: false)
      add(:provider_account_key, :string)
      add(:source_key, :string)
      add(:state, :string, null: false, default: "queued")
      add(:attempt_number, :integer, null: false, default: 0)
      add(:fencing_version, :bigint, null: false, default: 0)
      add(:lock_version, :bigint, null: false, default: 1)
      add(:next_attempt_at, :utc_datetime)
      add(:provider_message_id, :string)
      add(:failure_class, :string)

      timestamps(type: :utc_datetime)
    end

    create(
      unique_index(:external_create_operations, [:id, :support_case_id],
        name: :external_create_operations_id_case_uidx
      )
    )

    create table(:conversation_closures) do
      add(:support_case_id, references(:support_cases, on_delete: :restrict), null: false)
      add(:closure_epoch, :bigint, null: false)
      add(:state, :string, null: false)
      add(:case_version, :bigint, null: false)
      add(:fence_sequence, :bigint)
      add(:actor_id, :string)
      add(:requested_at, :utc_datetime, null: false)
      add(:resolved_at, :utc_datetime)
      add(:recovery_reason, :string)

      timestamps(type: :utc_datetime)
    end

    create(
      unique_index(:conversation_closures, [:id, :support_case_id],
        name: :conversation_closures_id_case_uidx
      )
    )

    create table(:support_case_events) do
      add(:support_case_id, references(:support_cases, on_delete: :restrict), null: false)

      add(
        :support_message_id,
        references(:support_messages,
          with: [support_case_id: :support_case_id],
          on_delete: :restrict
        )
      )

      add(
        :external_create_operation_id,
        references(:external_create_operations,
          with: [support_case_id: :support_case_id],
          on_delete: :restrict
        )
      )

      add(
        :conversation_closure_id,
        references(:conversation_closures,
          with: [support_case_id: :support_case_id],
          on_delete: :restrict
        )
      )

      add(:sequence, :bigint, null: false)
      add(:event_type, :string, null: false)
      add(:actor_type, :string, null: false)
      add(:actor_id, :string, null: false)
      add(:provider_account_key, :string)
      add(:provider_message_id, :string)
      add(:case_version, :bigint, null: false)
      add(:metadata, :map, null: false, default: %{})

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create(
      constraint(:support_cases, :support_cases_state_valid,
        check: "state IN ('#{Enum.join(@case_states, "','")}')"
      )
    )

    create(
      constraint(:support_cases, :support_cases_generation_positive, check: "generation > 0")
    )

    create(
      constraint(:support_cases, :support_cases_next_message_sequence_positive,
        check: "next_message_sequence > 0"
      )
    )

    create(
      constraint(:support_cases, :support_cases_lock_version_positive, check: "lock_version > 0")
    )

    create(
      constraint(:support_messages, :support_messages_direction_valid,
        check: "direction IN ('customer', 'operator', 'system')"
      )
    )

    create(
      constraint(:support_messages, :support_messages_sequence_positive, check: "sequence > 0")
    )

    create(
      constraint(:external_create_operations, :external_create_operations_state_valid,
        check: "state IN ('#{Enum.join(@operation_states, "','")}')"
      )
    )

    create(
      constraint(:external_create_operations, :external_create_operations_uuid_v7,
        check:
          "substring(operation_id::text from 15 for 1) = '7' " <>
            "AND substring(operation_id::text from 20 for 1) IN ('8', '9', 'a', 'b')"
      )
    )

    create(
      constraint(
        :external_create_operations,
        :external_create_operations_attempt_number_non_negative,
        check: "attempt_number >= 0"
      )
    )

    create(
      constraint(
        :external_create_operations,
        :external_create_operations_fencing_version_non_negative,
        check: "fencing_version >= 0"
      )
    )

    create(
      constraint(:external_create_operations, :external_create_operations_lock_version_positive,
        check: "lock_version > 0"
      )
    )

    create(
      constraint(:conversation_closures, :conversation_closures_state_valid,
        check: "state IN ('#{Enum.join(@closure_states, "','")}')"
      )
    )

    create(
      constraint(:conversation_closures, :conversation_closures_epoch_positive,
        check: "closure_epoch > 0"
      )
    )

    create(
      constraint(:conversation_closures, :conversation_closures_case_version_positive,
        check: "case_version > 0"
      )
    )

    create(
      constraint(:support_case_events, :support_case_events_case_version_positive,
        check: "case_version > 0"
      )
    )

    create(
      constraint(:support_case_events, :support_case_events_sequence_positive,
        check: "sequence > 0"
      )
    )

    create(
      unique_index(:support_cases, [:conversation_id, :generation],
        name: :support_cases_conversation_generation_uidx
      )
    )

    create(
      unique_index(:support_cases, [:conversation_id],
        where: "state IN ('waiting', 'claimed')",
        name: :support_cases_one_active_per_conversation_uidx
      )
    )

    create(index(:support_cases, [:state, :requested_at, :id], name: :support_cases_queue_idx))

    create(
      index(:support_cases, [:assigned_operator_id, :state, :updated_at, :id],
        name: :support_cases_assignment_idx
      )
    )

    create(
      unique_index(:support_messages, [:support_case_id, :sequence],
        name: :support_messages_case_sequence_uidx
      )
    )

    create(
      index(:support_messages, [:support_case_id, desc: :sequence],
        name: :support_messages_case_sequence_desc_idx
      )
    )

    create(
      unique_index(:external_create_operations, [:operation_id],
        name: :external_create_operations_operation_id_uidx
      )
    )

    create(
      unique_index(:external_create_operations, [:support_message_id, :provider, :operation_kind],
        name: :external_create_operations_message_provider_kind_uidx
      )
    )

    create(
      index(:external_create_operations, [:state, :next_attempt_at, :id],
        name: :external_create_operations_due_work_idx
      )
    )

    create(
      unique_index(:conversation_closures, [:support_case_id, :closure_epoch],
        name: :conversation_closures_case_epoch_uidx
      )
    )

    create(
      unique_index(:conversation_closures, [:support_case_id],
        where: "state IN ('requested', 'fenced', 'reconciling', 'recovery_required')",
        name: :conversation_closures_one_active_per_case_uidx
      )
    )

    create(
      index(:conversation_closures, [:support_case_id, :state],
        name: :conversation_closures_case_state_idx
      )
    )

    create(
      unique_index(:support_case_events, [:support_case_id, :sequence],
        name: :support_case_events_case_sequence_uidx
      )
    )
  end
end
