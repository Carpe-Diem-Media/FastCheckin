defmodule FastCheck.Repo.Migrations.EnforceSupportIdentities do
  use Ecto.Migration

  def change do
    create(
      constraint(:support_messages, :support_messages_operator_identity_required,
        check:
          "direction <> 'operator' OR (" <>
            "provider_account_key IS NOT NULL AND provider_account_key ~ '[^[:space:]]' " <>
            "AND client_submission_id IS NOT NULL AND client_submission_id ~ '[^[:space:]]')"
      )
    )

    create(
      constraint(:support_messages, :support_messages_customer_identity_required,
        check:
          "direction <> 'customer' OR (" <>
            "provider_account_key IS NOT NULL AND provider_account_key ~ '[^[:space:]]' " <>
            "AND provider_message_id IS NOT NULL AND provider_message_id ~ '[^[:space:]]')"
      )
    )

    create(
      constraint(:support_case_events, :support_case_events_customer_exit_identity_required,
        check:
          "event_type <> 'customer_exit' OR (" <>
            "provider_account_key IS NOT NULL AND provider_account_key ~ '[^[:space:]]' " <>
            "AND provider_message_id IS NOT NULL AND provider_message_id ~ '[^[:space:]]')"
      )
    )

    create(
      unique_index(:support_messages, [:provider_account_key, :client_submission_id],
        where: "direction = 'operator'",
        name: :support_messages_operator_submission_uidx
      )
    )

    create(
      unique_index(:support_messages, [:provider_account_key, :provider_message_id],
        where: "direction = 'customer'",
        name: :support_messages_customer_wamid_uidx
      )
    )

    create(
      unique_index(:support_case_events, [:provider_account_key, :provider_message_id],
        where: "event_type = 'customer_exit'",
        name: :support_case_events_customer_exit_wamid_uidx
      )
    )
  end
end
