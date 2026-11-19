defmodule FastCheck.Repo.Migrations.IndexResendMissingCanonicalEmail do
  use Ecto.Migration

  def change do
    create(
      index(:sales_orders, [:status, :id],
        name: :sales_orders_resend_missing_canonical_idx,
        where: "buyer_email_canonical IS NULL"
      )
    )
  end
end
