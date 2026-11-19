defmodule FastCheck.Sales.TicketResendChallengeInspectTest do
  use ExUnit.Case, async: true

  alias FastCheck.Sales.{TicketIssue, TicketResendChallenge}

  test "inspect exposes only the safe lifecycle map for all relationship states" do
    marker = fn name -> "private_sentinel_#{name}_92bd" end

    ids = %{
      id: 901_234_561,
      sales_order_id: 901_234_562,
      ticket_issue_id: 901_234_563,
      conversation_id: 901_234_564
    }

    private =
      Map.new(
        [
          :public_id,
          :request_email_hash,
          :request_name_hash,
          :source_hash,
          :candidate_hash,
          :otp_hash,
          :failure_reason
        ],
        &{&1, marker.(&1)}
      )
      |> Map.merge(ids)
      |> Map.merge(%{
        metadata:
          Map.new([:email, :name, :phone, :otp, :application_metadata], &{&1, marker.(&1)}),
        __metadata__: %{value: marker.(:ash_metadata)},
        __meta__: %Ecto.Schema.Metadata{
          state: :loaded,
          source: marker.(:ecto_source),
          prefix: marker.(:ecto_prefix),
          context: %{value: marker.(:ecto_context)}
        },
        calculations: %{value: marker.(:calculations)},
        aggregates: %{value: marker.(:aggregates)}
      })

    for state <- [:unloaded_ash, :unloaded_ecto, :loaded],
        present <- [true, false],
        flags <- [true, false],
        options <- [[], [limit: :infinity, printable_limit: :infinity]] do
      relationships =
        Map.new([:order, :ticket_issue, :conversation], fn key ->
          value =
            case state do
              :unloaded_ash ->
                %Ash.NotLoaded{field: key, type: :relationship}

              :unloaded_ecto ->
                %Ecto.Association.NotLoaded{
                  __field__: key,
                  __owner__: TicketResendChallenge,
                  __cardinality__: :one
                }

              :loaded ->
                %{id: marker.(key), nested: %{secret: marker.(key)}}
            end

          {key, value}
        end)

      date = ~U[2026-12-01 00:00:00Z]

      values =
        Map.merge(private, relationships)
        |> Map.merge(%{
          public_id: if(present, do: marker.(:public_id), else: ""),
          status: "pending",
          failed_attempt_count: 3,
          expires_at: date,
          verified_at: if(flags, do: date),
          consumed_at: if(flags, do: date),
          locked_until: if(flags, do: date)
        })

      safe = %{
        public_id_present?: present,
        status: "pending",
        failed_attempt_count: 3,
        expires_at: date,
        verified?: flags,
        consumed?: flags,
        locked?: flags
      }

      output = inspect(struct!(TicketResendChallenge, values), options)
      assert output == "#FastCheck.Sales.TicketResendChallenge<" <> inspect(safe, options) <> ">"
      refute output =~ "private_sentinel_"
      for id <- Map.values(ids), do: refute(output =~ to_string(id))
    end
  end

  test "the opt-out retains generated resource APIs and other resources retain their inspector" do
    refute Ash.Resource.Info.generate_inspect?(TicketResendChallenge)
    assert Ash.Resource.Info.generate_inspect?(TicketIssue)

    assert Inspect.impl_for(%TicketResendChallenge{}) ==
             Inspect.FastCheck.Sales.TicketResendChallenge

    assert Inspect.impl_for(%TicketIssue{}) == Inspect.FastCheck.Sales.TicketIssue
    assert TicketResendChallenge.default_short_name() == :ticket_resend_challenge
    assert TicketResendChallenge.primary_key_matches?(%{id: 1}, %{id: 1})
    refute TicketResendChallenge.primary_key_matches?(%{id: 1}, %{id: 2})
    assert TicketResendChallenge.input(id: 1) == %{id: 1}

    assert TicketResendChallenge.input([public_id: "safe"], :create_pending) == %{
             public_id: "safe"
           }
  end
end
