defmodule FastCheck.Repo.Migrations.IndexResendOrderIssue do
  use Ecto.Migration

  def change do
    create(
      index(:sales_ticket_issues, [:sales_order_id, :id],
        name: :sales_ticket_issues_resend_order_id_idx
      )
    )
  end
end
