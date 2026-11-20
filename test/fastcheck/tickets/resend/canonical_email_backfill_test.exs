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

    populate_catalogue(seed, 1, 4_000)

    for {name, count} <- [{"one", 1}, {"nine", 9}] do
      for _ <- 1..count, do: issued_ticket_candidate!(buyer_email: "plan-#{name}@example.com")
    end

    [preferred, other] =
      for _ <- 1..2, do: issued_ticket_candidate!(buyer_email: "plan-two@example.com")

    Repo.update_all(from(o in "sales_orders", where: o.id == ^preferred.order_id),
      set: [buyer_phone: "+27821234567", inserted_at: ~U[2020-01-01 00:00:00Z]]
    )

    Repo.update_all(from(o in "sales_orders", where: o.id == ^other.order_id),
      set: [buyer_phone: "+27820000000"]
    )

    multiple = issued_ticket_candidate!(buyer_email: "plan-multiple@example.com")
    add_multiple_tickets(multiple)

    assert [%{ticket_issue_id: preferred_id}, %{ticket_issue_id: other_id}] =
             Eligibility.candidates_for_email("plan-two@example.com", "+27821234567")

    assert preferred_id == preferred.ticket_issue_id
    assert other_id == other.ticket_issue_id

    expected_multiple =
      Repo.all(
        from ti in "sales_ticket_issues",
          join: a in "attendees",
          on: a.id == ti.attendee_id,
          where: ti.sales_order_id == ^multiple.order_id and a.scan_eligibility == "active",
          order_by: [desc: ti.id],
          select: ti.id
      )

    assert length(expected_multiple) == 10

    assert Enum.map(
             Eligibility.candidates_for_email("plan-multiple@example.com", nil),
             & &1.ticket_issue_id
           ) == expected_multiple

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
    small = measure_discovery("small")
    populate_catalogue(seed, 4_001, 20_000)

    for table <- ["sales_orders", "sales_ticket_issues", "attendees", "events"],
        do: Repo.query!("ANALYZE " <> table)

    large = measure_discovery("large")

    for name <- Map.keys(small) do
      # Compare root buffer work, not the sum of cumulative node buffers.
      assert large[name]["Shared Hit Blocks"] <= small[name]["Shared Hit Blocks"] + 600
    end

    IO.puts(
      "SALES04_PLAN_EVIDENCE " <>
        Jason.encode!(%{
          coverage: plan_metrics(complete),
          missing: plan_metrics(missing),
          catalogue_sizes: [4_000, 20_000],
          note: "Synthetic envelope; production cardinalities are unknown",
          discovery_small: small,
          discovery_large: large
        })
    )
  end

  defp populate_catalogue(seed, first, last) do
    Repo.query!(
      """
      INSERT INTO sales_orders (public_reference, event_id, buyer_email, buyer_email_canonical, source_channel, status, total_amount_cents, currency, inserted_at, updated_at)
      SELECT 'PLAN-' || $1::text || '-' || $3::integer::text || '-' || n, $2, CASE WHEN n <= 100 THEN 'plan-fanout@example.com' ELSE 'covered' || n || '@example.com' END, CASE WHEN n <= 100 THEN 'plan-fanout@example.com' ELSE 'covered' || n || '@example.com' END, 'test', 'ticket_issued', 100, 'ZAR', now(), now()
      FROM generate_series($3::integer, $4::integer) AS n
      """,
      [Integer.to_string(seed.order_id), seed.event.id, first, last]
    )

    prefix = "PLAN-#{seed.order_id}-#{first}-%"

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
  end

  defp add_multiple_tickets(seed) do
    prefix = "MULTI-#{seed.order_id}-"

    Repo.query!(
      """
      INSERT INTO attendees (event_id, ticket_code, payment_status, scan_eligibility, inserted_at, updated_at)
      SELECT $1, $2 || n, 'completed', CASE WHEN n >= 10 THEN 'not_scannable' ELSE 'active' END, now(), now()
      FROM generate_series(1, 12) n
      """,
      [seed.event.id, prefix]
    )

    Repo.query!(
      """
      INSERT INTO sales_ticket_issues (sales_order_id, sales_order_line_id, line_item_sequence, attendee_id, ticket_code, qr_token_hash, delivery_token_hash, delivery_token_expires_at, status, scanner_status, inserted_at, updated_at)
      SELECT $1, l.id, n + 1, a.id, a.ticket_code, 'qr-' || a.ticket_code, 'delivery-' || a.ticket_code, now() + interval '1 hour', 'issued', 'valid', now(), now()
      FROM sales_order_lines l CROSS JOIN generate_series(1, 12) n
      JOIN attendees a ON a.event_id = $2 AND a.ticket_code = $3 || n
      WHERE l.sales_order_id = $1
      """,
      [seed.order_id, seed.event.id, prefix]
    )
  end

  defp measure_discovery(label) do
    cases = [{"zero", 0}, {"one", 1}, {"two", 2}, {"nine", 9}, {"multiple", 10}, {"fanout", 10}]

    Map.new(cases, fn {name, expected} ->
      email = "plan-#{name}@example.com"
      query = Eligibility.candidates_query(email, "+27821234567")
      plan = explain(query)
      rows = Repo.all(query, log: false)
      assert length(rows) == expected
      nodes = plan_nodes(plan)

      # A plan may contain a never-executed scan; executed ticket work must
      # use the order index and remain proportional to the matching orders.
      refute Enum.any?(nodes, fn node ->
               node["Relation Name"] == "sales_ticket_issues" and
                 node["Node Type"] == "Seq Scan" and (node["Actual Loops"] || 0) > 0
             end)

      if expected > 0 do
        assert Enum.any?(nodes, fn node ->
                 node["Index Name"] in [
                   "sales_ticket_issues_resend_order_id_idx",
                   "sales_ticket_issues_sales_order_id_idx",
                   "sales_ticket_issues_sales_order_id_status_idx"
                 ] and
                   (node["Actual Loops"] || 0) > 0
               end)
      end

      ticket_rows =
        nodes
        |> Enum.filter(&(&1["Relation Name"] == "sales_ticket_issues"))
        |> Enum.map(fn node ->
          ((node["Actual Rows"] || 0) + (node["Rows Removed by Filter"] || 0)) *
            (node["Actual Loops"] || 0)
        end)
        |> Enum.sum()

      assert ticket_rows <= if(name == "fanout", do: 150, else: 20)

      {name,
       %{
         "label" => label,
         "Shared Hit Blocks" => plan["Shared Hit Blocks"],
         "ticket_rows" => ticket_rows,
         "nodes" => plan_metrics(plan)
       }}
    end)
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
