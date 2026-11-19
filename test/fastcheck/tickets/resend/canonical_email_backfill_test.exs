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

  test "normal planner uses the missing-key index for complete coverage and bounded discovery" do
    seed = issued_ticket_candidate!(buyer_email: "plan-fanout@example.com")

    for n <- 1..24 do
      issued_ticket_candidate!(
        buyer_email: "plan-fanout@example.com",
        attendee_first_name: "Guest#{n}"
      )
    end

    Repo.query!(
      """
      INSERT INTO sales_orders (public_reference, event_id, buyer_email, buyer_email_canonical, source_channel, status, total_amount_cents, currency, inserted_at, updated_at)
      SELECT 'PLAN-' || $1::text || '-' || n, $2, CASE WHEN n <= 100 THEN 'plan-fanout@example.com' ELSE 'covered' || n || '@example.com' END, CASE WHEN n <= 100 THEN 'plan-fanout@example.com' ELSE 'covered' || n || '@example.com' END, 'test', 'ticket_issued', 100, 'ZAR', now(), now()
      FROM generate_series(1, 4000) AS n
      """,
      [seed.order_id, seed.event.id]
    )

    prefix = "PLAN-#{seed.order_id}-%"

    Repo.query!(
      """
      INSERT INTO sales_order_lines (sales_order_id, ticket_offer_id, line_number, ticket_type, offer_name_snapshot, event_name_snapshot, quantity, unit_amount_cents, total_amount_cents, currency, metadata, inserted_at, updated_at)
      SELECT o.id, l.ticket_offer_id, 1, 'General Admission', 'General Admission', 'Event', 1, 100, 100, 'ZAR', '{}', now(), now()
      FROM sales_orders o JOIN sales_order_lines l ON l.sales_order_id = $1
      WHERE o.public_reference LIKE $2
      """,
      [seed.order_id, prefix]
    )

    Repo.query!(
      """
      INSERT INTO attendees (event_id, ticket_code, payment_status, scan_eligibility, inserted_at, updated_at)
      SELECT event_id, public_reference, 'completed', 'active', now(), now() FROM sales_orders WHERE public_reference LIKE $1
      """,
      [prefix]
    )

    Repo.query!(
      """
      INSERT INTO sales_ticket_issues (sales_order_id, sales_order_line_id, line_item_sequence, attendee_id, ticket_code, qr_token_hash, delivery_token_hash, delivery_token_expires_at, status, scanner_status, inserted_at, updated_at)
      SELECT o.id, l.id, 1, a.id, o.public_reference, 'qr-' || o.public_reference, 'delivery-' || o.public_reference, now() + interval '1 hour', 'issued', 'valid', now(), now()
      FROM sales_orders o JOIN sales_order_lines l ON l.sales_order_id = o.id JOIN attendees a ON a.event_id = o.event_id AND a.ticket_code = o.public_reference
      WHERE o.public_reference LIKE $1
      """,
      [prefix]
    )

    for table <- ["sales_orders", "sales_ticket_issues", "attendees", "events"],
        do: Repo.query!("ANALYZE " <> table)

    complete = explain(Eligibility.canonical_coverage_query())
    nodes = plan_nodes(complete)
    assert Enum.any?(nodes, &(&1["Index Name"] == "sales_orders_resend_missing_canonical_idx"))

    missing_index =
      Enum.find(nodes, &(&1["Index Name"] == "sales_orders_resend_missing_canonical_idx"))

    assert missing_index["Actual Rows"] == 0

    assert Enum.all?(nodes, fn node ->
             node["Relation Name"] not in ["sales_ticket_issues", "attendees", "events"] or
               (node["Actual Rows"] || 0) * (node["Actual Loops"] || 0) <= 10
           end)

    assert Eligibility.canonical_coverage_complete?()

    Repo.update_all(from(o in "sales_orders", where: o.id == ^seed.order_id),
      set: [buyer_email_canonical: nil]
    )

    Repo.query!("ANALYZE sales_orders")
    missing = explain(Eligibility.canonical_coverage_query())

    assert Enum.any?(
             plan_nodes(missing),
             &(&1["Index Name"] == "sales_orders_resend_missing_canonical_idx")
           )

    refute Eligibility.canonical_coverage_complete?()

    Repo.update_all(from(o in "sales_orders", where: o.id == ^seed.order_id),
      set: [buyer_email_canonical: "plan-fanout@example.com"]
    )

    Repo.query!("ANALYZE sales_orders")
    query = Eligibility.candidates_query("plan-fanout@example.com", "+27821234567")
    discovery = explain(query)
    assert length(Repo.all(query, log: false)) == 10

    assert Enum.any?(
             plan_nodes(discovery),
             &(&1["Index Name"] == "sales_orders_buyer_email_canonical_idx")
           )

    IO.puts(
      "SALES04_PLAN_EVIDENCE " <>
        Jason.encode!(%{
          coverage: plan_metrics(complete),
          missing: plan_metrics(missing),
          matching_orders: 125,
          fanout: plan_metrics(discovery)
        })
    )
  end

  defp explain(query) do
    {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)

    %{rows: [[[%{"Plan" => plan}]]]} =
      Repo.query!("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " <> sql, params, log: false)

    plan
  end

  defp plan_nodes(node), do: [node | Enum.flat_map(Map.get(node, "Plans", []), &plan_nodes/1)]

  defp plan_metrics(plan) do
    Enum.map(plan_nodes(plan), fn node ->
      Map.take(node, [
        "Node Type",
        "Index Name",
        "Relation Name",
        "Actual Rows",
        "Actual Loops",
        "Rows Removed by Filter",
        "Shared Hit Blocks",
        "Shared Read Blocks"
      ])
    end)
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
