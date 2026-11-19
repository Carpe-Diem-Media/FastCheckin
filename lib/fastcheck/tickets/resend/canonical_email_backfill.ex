defmodule FastCheck.Tickets.Resend.CanonicalEmailBackfill do
  @moduledoc """
  Bounded primary-key reconciliation for the server-owned resend email key.

  Run only in an explicitly authorized rollout. Callers persist the returned
  cursor, repeat until `done?`, then run a second complete verification pass.
  Counts contain no customer data. Compare-and-set avoids overwriting a
  concurrent change to the source email; a conflict requires another pass.
  """
  import Ecto.Query

  alias FastCheck.Repo
  alias FastCheck.Tickets.Resend.Request

  @max_batch 500

  def batch(after_id, limit)
      when is_integer(after_id) and after_id >= 0 and limit in 1..@max_batch do
    rows =
      Repo.all(
        from o in "sales_orders",
          where: o.id > ^after_id,
          order_by: o.id,
          limit: ^limit,
          select: %{id: o.id, email: o.buyer_email, canonical: o.buyer_email_canonical}
      )

    counts = Enum.reduce(rows, %{updated: 0, invalid: 0, conflicts: 0}, &reconcile_record/2)

    Map.merge(counts, %{
      next_id: if(rows == [], do: after_id, else: List.last(rows).id),
      done?: length(rows) < limit
    })
  end

  @doc false
  def reconcile_record(row, counts) do
    canonical =
      case Request.normalize_email(row.email) do
        {:ok, value} -> value
        _ -> nil
      end

    counts = if is_nil(canonical), do: Map.update!(counts, :invalid, &(&1 + 1)), else: counts

    if canonical == row.canonical do
      counts
    else
      query = from o in "sales_orders", where: o.id == ^row.id

      query =
        if is_nil(row.email),
          do: from(o in query, where: is_nil(o.buyer_email)),
          else: from(o in query, where: fragment("? COLLATE \"C\"", o.buyer_email) == ^row.email)

      query =
        if is_nil(row.canonical),
          do: from(o in query, where: is_nil(o.buyer_email_canonical)),
          else:
            from(o in query,
              where: fragment("? COLLATE \"C\"", o.buyer_email_canonical) == ^row.canonical
            )

      {count, _} = Repo.update_all(query, [set: [buyer_email_canonical: canonical]], log: false)
      key = if count == 1, do: :updated, else: :conflicts
      Map.update!(counts, key, &(&1 + 1))
    end
  end
end
