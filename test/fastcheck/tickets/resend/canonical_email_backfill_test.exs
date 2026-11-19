defmodule FastCheck.Tickets.Resend.CanonicalEmailBackfillTest do
  use FastCheck.DataCase, async: false
  import Ecto.Query
  import FastCheck.TicketResendFixtures
  alias FastCheck.Repo
  alias FastCheck.Tickets.Resend.CanonicalEmailBackfill
  alias FastCheck.Tickets.Resend.Eligibility
  alias FastCheck.Tickets.Resend.Request

  test "bounded reconciliation uses the same Unicode normalizer and preserves raw email" do
    raw = "\u2003İ@example.com\t"
    candidate = issued_ticket_candidate!(buyer_email: raw)

    Repo.update_all(from(o in "sales_orders", where: o.id == ^candidate.order_id),
      set: [buyer_email_canonical: nil]
    )

    refute Eligibility.canonical_coverage_complete?()

    assert %{updated: 1, conflicts: 0, next_id: id} =
             CanonicalEmailBackfill.batch(candidate.order_id - 1, 1)

    assert id == candidate.order_id
    {:ok, normalized} = Request.normalize_email(raw)

    assert Repo.one!(
             from o in "sales_orders",
               where: o.id == ^id,
               select: {o.buyer_email, o.buyer_email_canonical}
           ) == {raw, normalized}

    assert Enum.any?(
             Eligibility.candidates_for_email(normalized, "+27821234567"),
             &(&1.ticket_issue_id == candidate.ticket_issue_id)
           )
  end

  test "invalid historical email remains explicit and blocks coverage" do
    candidate = issued_ticket_candidate!()

    Repo.update_all(from(o in "sales_orders", where: o.id == ^candidate.order_id),
      set: [buyer_email: "invalid", buyer_email_canonical: "stale@example.com"]
    )

    assert %{invalid: 1, updated: 1, conflicts: 0} =
             CanonicalEmailBackfill.batch(candidate.order_id - 1, 1)

    refute Eligibility.canonical_coverage_complete?()

    assert Repo.one(
             from o in "sales_orders",
               where: o.id == ^candidate.order_id,
               select: o.buyer_email_canonical
           ) == nil
  end

  test "a concurrent source change cannot be overwritten by a stale backfill read" do
    candidate = issued_ticket_candidate!(buyer_email: "before@example.com")
    stale = %{id: candidate.order_id, email: "before@example.com", canonical: nil}

    Repo.update_all(from(o in "sales_orders", where: o.id == ^candidate.order_id),
      set: [buyer_email: "after@example.com", buyer_email_canonical: nil]
    )

    result =
      CanonicalEmailBackfill.reconcile_record(stale, %{updated: 0, invalid: 0, conflicts: 0})

    assert result.conflicts == 1

    assert Repo.one!(
             from o in "sales_orders",
               where: o.id == ^candidate.order_id,
               select: {o.buyer_email, o.buyer_email_canonical}
           ) == {"after@example.com", nil}
  end

  test "the canonical exact-match predicate can use its index" do
    Repo.query!("SET LOCAL enable_seqscan = off")

    result =
      Repo.query!(
        "EXPLAIN SELECT id FROM sales_orders WHERE buyer_email_canonical COLLATE \"C\" = $1 AND status = 'ticket_issued'",
        ["index@example.com"]
      )

    plan = Enum.map_join(result.rows, "\n", &hd/1)
    assert plan =~ "sales_orders_buyer_email_canonical_idx"
  end
end
