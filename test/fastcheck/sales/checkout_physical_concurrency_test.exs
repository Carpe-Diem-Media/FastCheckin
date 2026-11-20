defmodule FastCheck.Sales.CheckoutPhysicalConcurrencyTest do
  use ExUnit.Case, async: false
  @moduletag :independent_db

  alias Ecto.Adapters.SQL.Sandbox
  alias FastCheck.Repo
  alias FastCheck.Sales.Checkout
  alias FastCheck.Sales.Inventory.ReservationLedger
  alias FastCheck.SalesCheckoutFixtures, as: Fixtures

  setup do
    config = Repo.config()

    unless System.get_env("GITHUB_ACTIONS") == "true" and
             System.get_env("GITHUB_JOB") == "independent-db" and
             config[:hostname] == "127.0.0.1" and config[:port] == 5432 and
             config[:database] == "fastcheck_test" and config[:username] == "fastcheck_test" do
      raise "independent database tests require the disposable CI job"
    end

    :ok
  end

  test "independent last-ticket checkouts cannot oversell while the winner waits to persist" do
    {event, offer, inputs} =
      unboxed(fn ->
        event = FastCheck.Fixtures.create_event()
        {:ok, _} = FastCheck.Events.enable_whatsapp_sales(event.id)
        offer = Fixtures.insert_offer!(event_id: event.id, configured_quantity_available: 1)

        inputs =
          for _ <- 1..2 do
            Fixtures.checkout_input(%{event_id: event.id, ticket_offer_id: offer.id})
          end

        {event, offer, inputs}
      end)

    parent = self()

    holder =
      Task.async(fn ->
        unboxed(fn ->
          Repo.transaction(fn ->
            %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
            Repo.query!("LOCK TABLE sales_orders IN SHARE MODE")
            send(parent, {:holder, self(), pid})

            receive do
              :release -> :ok
            after
              10_000 -> raise "lock holder timed out"
            end
          end)
        end)
      end)

    assert_receive {:holder, holder_pid, holder_db}, 5_000
    [first, second] = inputs

    winner =
      Task.async(fn ->
        unboxed(fn ->
          %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
          send(parent, {:winner, pid})

          Checkout.start_checkout(first, Fixtures.system_actor([event.id]),
            effective_sales_channel: "whatsapp"
          )
        end)
      end)

    assert_receive {:winner, winner_db}, 5_000
    assert winner_db != holder_db
    await_blocked(winner_db, holder_db, System.monotonic_time(:millisecond) + 5_000)

    loser =
      Task.async(fn ->
        unboxed(fn ->
          %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
          send(parent, {:loser, pid})

          Checkout.start_checkout(second, Fixtures.system_actor([event.id]),
            effective_sales_channel: "whatsapp"
          )
        end)
      end)

    assert_receive {:loser, loser_db}, 5_000
    assert length(Enum.uniq([holder_db, winner_db, loser_db])) == 3
    assert {:error, :insufficient_inventory} = Task.await(loser, 5_000)
    send(holder_pid, :release)
    assert {:ok, :ok} = Task.await(holder, 10_000)
    assert {:ok, %{order: order, checkout_session: session}} = Task.await(winner, 10_000)
    assert order.status == "awaiting_payment"
    assert session.status == "hold_attached"

    unboxed(fn ->
      assert %{rows: [[1, 1]]} =
               Repo.query!(
                 "SELECT count(*), coalesce(sum(l.quantity), 0) FROM sales_order_lines l JOIN sales_orders o ON o.id = l.sales_order_id WHERE l.ticket_offer_id = $1 AND o.status = 'awaiting_payment'",
                 [offer.id]
               )

      assert %{rows: [[1]]} =
               Repo.query!(
                 "SELECT count(*) FROM sales_checkout_sessions WHERE sales_order_id = $1 AND status = 'hold_attached'",
                 [order.id]
               )
    end)

    assert {:ok, inventory} = ReservationLedger.get_availability(offer.id)
    assert inventory.available_quantity == 0
    assert inventory.reserved_quantity == 1
  end

  defp await_blocked(pid, holder, deadline) do
    %{rows: [[blockers]]} =
      unboxed(fn -> Repo.query!("SELECT pg_blocking_pids($1)", [pid]) end)

    cond do
      holder in blockers ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        flunk("checkout did not reach held database lock")

      true ->
        Process.sleep(10)
        await_blocked(pid, holder, deadline)
    end
  end

  defp unboxed(fun), do: Sandbox.unboxed_run(Repo, fun)
end
