defmodule FastCheck.Support.SupportCaseLifecycleTest do
  use FastCheck.DataCase, async: false

  alias Ash.Changeset
  alias Ash.Query
  alias Ecto.Adapters.SQL.Sandbox
  alias FastCheck.Messaging.WhatsApp.Config
  alias FastCheck.Repo
  alias FastCheck.Support.SupportCase
  alias FastCheck.Support.SupportCaseEvent
  alias Plug.Conn
  alias Plug.Test, as: PlugTest

  @account_key "synthetic-support-account"

  setup do
    previous_account = Application.get_env(:fastcheck, :whatsapp_business_account_id)
    previous_phone = Application.get_env(:fastcheck, :whatsapp_phone_number_id)
    previous_global_access = Application.get_env(:fastcheck, :operations_global_access)

    Application.put_env(:fastcheck, :whatsapp_business_account_id, @account_key)
    Application.put_env(:fastcheck, :whatsapp_phone_number_id, "synthetic-support-phone")

    Application.put_env(:fastcheck, :operations_global_access,
      allowed_usernames: ["agent-a", "agent-b"]
    )

    on_exit(fn ->
      restore_env(:whatsapp_business_account_id, previous_account)
      restore_env(:whatsapp_phone_number_id, previous_phone)
      restore_env(:operations_global_access, previous_global_access)
    end)

    :ok
  end

  test "verified synthetic intake creates a waiting case and its first audit event" do
    conversation = insert_conversation!()
    actor = system_actor(:intake, conversation.wa_id)

    assert {:ok, support_case} = create_waiting(conversation.id, actor)
    assert support_case.conversation_id == conversation.id
    assert support_case.state == "waiting"
    assert support_case.lock_version == 1
    assert is_nil(support_case.assigned_operator_id)
    assert is_nil(support_case.claimed_at)
    assert is_nil(support_case.cancelled_at)

    assert [
             %{
               event_type: "intake_created",
               actor_type: "system",
               actor_id: "support_intake",
               sequence: 1,
               case_version: 1
             }
           ] = events(support_case.id)
  end

  test "claim and release update assignment, case version, and ordered audit events" do
    support_case = create_case!()
    operator = operator_conn("agent-a")

    assert {:ok, claimed} =
             transition(support_case, :claim, operator, %{expected_lock_version: 1})

    assert claimed.state == "claimed"
    assert claimed.assigned_operator_id == "agent-a"
    assert claimed.claimed_at
    assert claimed.lock_version == 2

    assert {:ok, released} =
             transition(claimed, :release, operator, %{expected_lock_version: 2})

    assert released.state == "waiting"
    assert is_nil(released.assigned_operator_id)
    assert is_nil(released.claimed_at)
    assert released.lock_version == 3

    assert Enum.map(events(released.id), &{&1.event_type, &1.sequence, &1.case_version}) == [
             {"intake_created", 1, 1},
             {"operator_claimed", 2, 2},
             {"operator_released", 3, 3}
           ]
  end

  test "verified customer exit cancels cases from waiting and claimed" do
    waiting_case = create_case!()
    waiting_exit = system_actor(:customer_exit, conversation_wa_id(waiting_case), "wamid-waiting")

    assert {:ok, cancelled_waiting} =
             transition(waiting_case, :customer_cancel, waiting_exit, %{
               expected_lock_version: 1
             })

    assert cancelled_waiting.state == "cancelled"
    assert cancelled_waiting.cancelled_at
    assert cancelled_waiting.lock_version == 2

    claimed_case = create_case!()
    operator = operator_conn("agent-a")

    assert {:ok, claimed} =
             transition(claimed_case, :claim, operator, %{expected_lock_version: 1})

    claimed_exit = system_actor(:customer_exit, conversation_wa_id(claimed), "wamid-claimed")

    assert {:ok, cancelled_claimed} =
             transition(claimed, :customer_cancel, claimed_exit, %{
               expected_lock_version: 2
             })

    assert cancelled_claimed.state == "cancelled"
    assert cancelled_claimed.cancelled_at
    assert cancelled_claimed.assigned_operator_id == "agent-a"
    assert cancelled_claimed.lock_version == 3

    assert Enum.map(events(cancelled_claimed.id), &{&1.event_type, &1.case_version}) == [
             {"intake_created", 1},
             {"operator_claimed", 2},
             {"customer_exit", 3}
           ]
  end

  test "stale versions and prohibited transitions do not mutate cases or write events" do
    support_case = create_case!()
    operator = operator_conn("agent-a")

    assert {:error, _} =
             transition(support_case, :release, operator, %{expected_lock_version: 1})

    assert {:error, _} =
             transition(support_case, :claim, operator, %{expected_lock_version: 2})

    assert case_state(support_case.id) == {"waiting", 1, nil, nil}
    assert length(events(support_case.id)) == 1

    assert {:ok, claimed} =
             transition(support_case, :claim, operator, %{expected_lock_version: 1})

    assert {:error, _} =
             transition(claimed, :claim, operator, %{expected_lock_version: 2})

    assert {:error, _} =
             transition(claimed, :release, operator, %{expected_lock_version: 1})

    assert case_state(support_case.id) == {"claimed", 2, "agent-a", nil}
    assert length(events(support_case.id)) == 2

    exit_actor = system_actor(:customer_exit, conversation_wa_id(claimed), "wamid-exit")

    assert {:ok, cancelled} =
             transition(claimed, :customer_cancel, exit_actor, %{expected_lock_version: 2})

    assert {:error, _} = transition(cancelled, :claim, operator, %{expected_lock_version: 3})
    assert {:error, _} = transition(cancelled, :release, operator, %{expected_lock_version: 3})

    assert {:error, _} =
             transition(cancelled, :customer_cancel, exit_actor, %{expected_lock_version: 3})

    assert case_state(support_case.id) ==
             {"cancelled", 3, "agent-a", DateTime.to_naive(cancelled.cancelled_at)}

    assert length(events(support_case.id)) == 3
  end

  test "resolved cases stay terminal for claim, release, and customer cancellation" do
    {conversation_id, case_id, wa_id} = committed_case!("resolved", nil, 1)
    on_exit(fn -> delete_committed_case!(conversation_id, case_id) end)

    support_case = get_case!(case_id)
    operator = operator_conn("agent-a")
    customer_exit = system_actor(:customer_exit, wa_id, "wamid-resolved")

    assert {:error, _} =
             transition(support_case, :claim, operator, %{expected_lock_version: 1})

    assert {:error, _} =
             transition(support_case, :release, operator, %{expected_lock_version: 1})

    assert {:error, _} =
             transition(support_case, :customer_cancel, customer_exit, %{
               expected_lock_version: 1
             })

    assert {"resolved", 1, nil, nil} = committed_case_state(case_id)
    assert length(committed_events(case_id)) == 1
  end

  test "no generic update, resolution, reopen, or administrative-close action is callable" do
    action_names = Enum.map(Ash.Resource.Info.actions(SupportCase), & &1.name)
    event_action_names = Enum.map(Ash.Resource.Info.actions(SupportCaseEvent), & &1.name)

    assert :create_waiting in action_names
    assert :claim in action_names
    assert :release in action_names
    assert :customer_cancel in action_names
    assert :get_by_id in action_names
    refute :create in action_names
    refute :update in action_names
    refute :resolve in action_names
    refute :reopen in action_names
    refute :admin_close in action_names
    refute :request_resolution in action_names
    refute :record_lifecycle_event in event_action_names
    refute :create in event_action_names
  end

  test "an authorized operator cannot create forged lifecycle events directly" do
    support_case = create_case!()
    operator = operator_conn("agent-a")

    forged_events = [
      %{
        support_case_id: support_case.id,
        sequence: 2,
        event_type: "operator_claimed",
        actor_type: "operator",
        actor_id: "agent-a",
        provider_account_key: @account_key,
        case_version: 2,
        metadata: %{from_state: "waiting", to_state: "claimed"}
      },
      %{
        support_case_id: support_case.id,
        sequence: 3,
        event_type: "customer_exit",
        actor_type: "customer",
        actor_id: Integer.to_string(support_case.conversation_id),
        provider_account_key: @account_key,
        provider_message_id: "wamid-forged-event",
        case_version: 2,
        metadata: %{from_state: "waiting", to_state: "cancelled"}
      }
    ]

    for attrs <- forged_events do
      assert {:error, _} = direct_event_create(attrs, operator)
    end

    assert case_state(support_case.id) == {"waiting", 1, nil, nil}
    assert length(events(support_case.id)) == 1
  end

  test "only one of two concurrent claims with the same expected version succeeds" do
    {conversation_id, case_id, wa_id} = committed_case!()
    on_exit(fn -> delete_committed_case!(conversation_id, case_id) end)

    results =
      concurrent_actions([
        {:claim, operator_conn("agent-a"), 1, wa_id},
        {:claim, operator_conn("agent-b"), 1, wa_id}
      ])

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, _}, &1)) == 1

    assert {"claimed", 2, assigned_to, nil} = committed_case_state(case_id)
    assert assigned_to in ["agent-a", "agent-b"]
    assert length(committed_events(case_id)) == 2
  end

  test "only one of two concurrent releases with the same expected version succeeds" do
    {conversation_id, case_id, wa_id} = committed_case!("claimed", "agent-a", 2)
    on_exit(fn -> delete_committed_case!(conversation_id, case_id) end)

    results =
      concurrent_actions([
        {:release, operator_conn("agent-a"), 2, wa_id},
        {:release, operator_conn("agent-a"), 2, wa_id}
      ])

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, _}, &1)) == 1
    assert {"waiting", 3, nil, nil} = committed_case_state(case_id)

    assert committed_events(case_id) == [
             ["intake_created"],
             ["operator_claimed"],
             ["operator_released"]
           ]
  end

  test "a claim-first stale customer exit still cancels the current case" do
    {conversation_id, case_id, wa_id} = committed_case!()
    on_exit(fn -> delete_committed_case!(conversation_id, case_id) end)
    exit_actor = system_actor(:customer_exit, wa_id, "wamid-race-exit")

    [claim_task, exit_task] =
      prepare_concurrent_actions([
        {:claim, operator_conn("agent-a"), 1, wa_id},
        {:customer_cancel, exit_actor, 1, wa_id}
      ])

    assert {:ok, _claimed} = run_prepared_action(claim_task)
    assert {:ok, cancelled} = run_prepared_action(exit_task)

    assert cancelled.state == "cancelled"
    assert {"cancelled", 3, "agent-a", cancelled_at} = committed_case_state(case_id)
    assert cancelled_at

    assert committed_event_details(case_id) == [
             ["intake_created", 1, nil, "waiting"],
             ["operator_claimed", 2, "waiting", "claimed"],
             ["customer_exit", 3, "claimed", "cancelled"]
           ]
  end

  test "a cancel-first race prevents a stale claim and keeps one customer exit event" do
    {conversation_id, case_id, wa_id} = committed_case!()
    on_exit(fn -> delete_committed_case!(conversation_id, case_id) end)
    exit_actor = system_actor(:customer_exit, wa_id, "wamid-cancel-first")

    [exit_task, claim_task] =
      prepare_concurrent_actions([
        {:customer_cancel, exit_actor, 1, wa_id},
        {:claim, operator_conn("agent-a"), 1, wa_id}
      ])

    assert {:ok, cancelled} = run_prepared_action(exit_task)
    assert {:error, _} = run_prepared_action(claim_task)

    assert cancelled.state == "cancelled"
    assert {"cancelled", 2, nil, cancelled_at} = committed_case_state(case_id)
    assert cancelled_at

    assert committed_event_details(case_id) == [
             ["intake_created", 1, nil, "waiting"],
             ["customer_exit", 2, "waiting", "cancelled"]
           ]
  end

  test "a previously consumed customer WAMID cannot cancel another case" do
    first_case = create_case!()
    second_case = create_case!()
    shared_wamid = "wamid-consumed-exit"

    first_exit = system_actor(:customer_exit, conversation_wa_id(first_case), shared_wamid)
    second_exit = system_actor(:customer_exit, conversation_wa_id(second_case), shared_wamid)

    assert {:ok, _cancelled} =
             transition(first_case, :customer_cancel, first_exit, %{expected_lock_version: 1})

    assert {:error, _} =
             transition(second_case, :customer_cancel, second_exit, %{expected_lock_version: 1})

    assert {"cancelled", 2, nil, cancelled_at} = case_state(first_case.id)
    assert cancelled_at
    assert case_state(second_case.id) == {"waiting", 1, nil, nil}
    assert length(events(first_case.id)) == 2
    assert length(events(second_case.id)) == 1
  end

  test "case and audit event both roll back when the event insert fails" do
    support_case = create_case!()
    conversation = insert_conversation!()
    install_event_failure_constraint!()
    actor = system_actor(:intake, conversation.wa_id)

    assert {:error, _} = create_waiting(conversation.id, actor)

    assert [[0]] =
             Repo.query!(
               "SELECT count(*) FROM support_cases WHERE conversation_id = $1",
               [conversation.id]
             ).rows

    operator = operator_conn("agent-a")

    assert {:error, _} =
             transition(support_case, :claim, operator, %{expected_lock_version: 1})

    assert {"waiting", 1, nil, nil} = case_state(support_case.id)
    assert length(events(support_case.id)) == 1
  end

  defp create_case! do
    conversation = insert_conversation!()
    actor = system_actor(:intake, conversation.wa_id)
    assert {:ok, support_case} = create_waiting(conversation.id, actor)
    support_case
  end

  defp create_waiting(conversation_id, actor) do
    SupportCase
    |> Changeset.for_create(:create_waiting, %{conversation_id: conversation_id}, actor: actor)
    |> Ash.create(authorize?: true)
  end

  defp transition(support_case, action, actor, params) do
    support_case
    |> Changeset.for_update(action, params, actor: actor)
    |> Ash.update(authorize?: true)
  end

  defp direct_event_create(attrs, actor) do
    Ash.create(SupportCaseEvent, attrs,
      action: :record_lifecycle_event,
      actor: actor,
      authorize?: true
    )
  rescue
    error -> {:error, error}
  end

  defp get_case!(id) do
    SupportCase
    |> Query.for_read(:get_by_id, %{id: id})
    |> Ash.read_one!(authorize?: false)
  end

  defp events(case_id) do
    Repo.query!(
      """
      SELECT event_type, actor_type, actor_id, sequence, case_version
      FROM support_case_events
      WHERE support_case_id = $1
      ORDER BY sequence
      """,
      [case_id]
    ).rows
    |> Enum.map(fn [event_type, actor_type, actor_id, sequence, case_version] ->
      %{
        event_type: event_type,
        actor_type: actor_type,
        actor_id: actor_id,
        sequence: sequence,
        case_version: case_version
      }
    end)
  end

  defp case_state(case_id) do
    [[state, lock_version, assigned_operator_id, cancelled_at]] =
      Repo.query!(
        "SELECT state, lock_version, assigned_operator_id, cancelled_at FROM support_cases WHERE id = $1",
        [case_id]
      ).rows

    {state, lock_version, assigned_operator_id, cancelled_at}
  end

  defp committed_case!(state \\ "waiting", assigned_operator_id \\ nil, lock_version \\ 1) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.transaction(fn ->
        conversation = insert_conversation!()

        [[case_id]] =
          Repo.query!(
            """
            INSERT INTO support_cases
              (public_id, conversation_id, generation, state, assigned_operator_id, requested_at,
               claimed_at, next_message_sequence, lock_version, inserted_at, updated_at)
            VALUES ($1, $2, 1, $3, $4, now(), CASE WHEN $3::varchar = 'claimed'::varchar THEN now() ELSE NULL END,
                    1, $5, now(), now())
            RETURNING id
            """,
            [
              Ecto.UUID.dump!(Ecto.UUID.generate()),
              conversation.id,
              state,
              assigned_operator_id,
              lock_version
            ]
          ).rows

        insert_event_sql!(
          case_id,
          1,
          "intake_created",
          "system",
          "support_intake",
          1,
          @account_key
        )

        if state == "claimed" do
          insert_event_sql!(
            case_id,
            2,
            "operator_claimed",
            "operator",
            assigned_operator_id,
            lock_version,
            @account_key
          )
        end

        {conversation.id, case_id, conversation.wa_id}
      end)
      |> case do
        {:ok, result} -> result
        {:error, reason} -> raise "could not create committed support fixture: #{inspect(reason)}"
      end
    end)
  end

  defp committed_case_state(case_id) do
    Sandbox.unboxed_run(Repo, fn ->
      [[state, lock_version, assigned_operator_id, cancelled_at]] =
        Repo.query!(
          "SELECT state, lock_version, assigned_operator_id, cancelled_at FROM support_cases WHERE id = $1",
          [case_id]
        ).rows

      {state, lock_version, assigned_operator_id, cancelled_at}
    end)
  end

  defp committed_events(case_id) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.query!(
        "SELECT event_type FROM support_case_events WHERE support_case_id = $1 ORDER BY sequence",
        [case_id]
      ).rows
    end)
  end

  defp committed_event_details(case_id) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.query!(
        """
        SELECT event_type, case_version, metadata->>'from_state', metadata->>'to_state'
        FROM support_case_events
        WHERE support_case_id = $1
        ORDER BY sequence
        """,
        [case_id]
      ).rows
    end)
  end

  defp delete_committed_case!(conversation_id, case_id) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.query!("DELETE FROM support_case_events WHERE support_case_id = $1", [case_id])
      Repo.query!("DELETE FROM support_cases WHERE id = $1", [case_id])
      Repo.query!("DELETE FROM sales_conversations WHERE id = $1", [conversation_id])
    end)
  end

  defp insert_event_sql!(
         case_id,
         sequence,
         event_type,
         actor_type,
         actor_id,
         case_version,
         account_key
       ) do
    Repo.query!(
      """
      INSERT INTO support_case_events
        (support_case_id, sequence, event_type, actor_type, actor_id,
         provider_account_key, case_version, metadata, inserted_at)
      VALUES (
        $1, $2, $3, $4, $5, $6, $7,
        CASE $3::varchar
          WHEN 'intake_created' THEN jsonb_build_object('from_state', NULL, 'to_state', 'waiting')
          WHEN 'operator_claimed' THEN jsonb_build_object('from_state', 'waiting', 'to_state', 'claimed')
          ELSE '{}'::jsonb
        END,
        now()
      )
      """,
      [case_id, sequence, event_type, actor_type, actor_id, account_key, case_version]
    )
  end

  defp concurrent_actions(actions) do
    tasks = prepare_concurrent_actions(actions)

    Enum.each(tasks, fn task -> send(task.pid, :run_support_action) end)
    Task.await_many(tasks, 15_000)
  end

  defp prepare_concurrent_actions(actions) do
    parent = self()

    tasks =
      Enum.map(actions, fn {action, actor, expected_lock_version, wa_id} ->
        Task.async(fn ->
          Sandbox.unboxed_run(Repo, fn ->
            support_case = get_case!(committed_case_id_for_wa!(wa_id))
            send(parent, {:support_action_ready, self()})

            receive do
              :run_support_action ->
                transition(support_case, action, actor, %{
                  expected_lock_version: expected_lock_version
                })
            after
              5_000 -> {:error, :test_barrier_timeout}
            end
          end)
        end)
      end)

    Enum.each(tasks, fn _task -> assert_receive {:support_action_ready, _pid}, 5_000 end)
    tasks
  end

  defp run_prepared_action(task) do
    send(task.pid, :run_support_action)
    Task.await(task, 15_000)
  end

  defp committed_case_id_for_wa!(wa_id) do
    case Repo.query!(
           "SELECT sc.id FROM support_cases sc JOIN sales_conversations c ON c.id = sc.conversation_id WHERE c.wa_id = $1",
           [wa_id]
         ).rows do
      [[id]] -> id
      _ -> raise "expected one support case for synthetic conversation"
    end
  end

  defp conversation_wa_id(%{conversation_id: conversation_id}) do
    [[wa_id]] =
      Repo.query!("SELECT wa_id FROM sales_conversations WHERE id = $1", [conversation_id]).rows

    wa_id
  end

  defp insert_conversation! do
    wa_id = "synthetic-support-#{System.unique_integer([:positive])}"

    [[id]] =
      Repo.query!(
        """
        INSERT INTO sales_conversations
          (phone_e164, wa_id, preferred_language, state, state_data, needs_human, inserted_at, updated_at)
        VALUES ($1, $2, 'en', 'main_menu', '{}', false, now(), now())
        RETURNING id
        """,
        [
          "+1555" <>
            String.pad_leading(Integer.to_string(System.unique_integer([:positive])), 7, "0"),
          wa_id
        ]
      ).rows

    %{id: id, wa_id: wa_id}
  end

  defp operator_conn(username) do
    PlugTest.conn(:get, "/")
    |> PlugTest.init_test_session(%{dashboard_username: username})
    |> Conn.assign(:current_user, %{id: username, username: username})
  end

  defp system_actor(kind, wa_id, provider_message_id \\ nil) do
    context = %{
      kind: kind,
      wa_id: wa_id,
      provider_account_key: Config.get().business_account_id,
      provider_message_id: provider_message_id
    }

    PlugTest.conn(:post, "/")
    |> Conn.put_private(:fastcheck_verified_support_actor, context)
  end

  defp install_event_failure_constraint! do
    Repo.query!(
      "ALTER TABLE support_case_events ADD CONSTRAINT support_case_test_reject_event CHECK (1 = 0) NOT VALID",
      []
    )
  end

  defp restore_env(key, nil), do: Application.delete_env(:fastcheck, key)
  defp restore_env(key, value), do: Application.put_env(:fastcheck, key, value)
end
