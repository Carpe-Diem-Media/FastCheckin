defmodule FastCheck.Support.SupportIdentityConstraintsTest do
  use FastCheck.DataCase, async: false

  alias Ash.Resource.Info, as: ResourceInfo
  alias AshPostgres.DataLayer.Info, as: PostgresInfo
  alias Ecto.Adapters.SQL.Sandbox
  alias FastCheck.Crypto
  alias FastCheck.Repo
  alias FastCheck.Support.SupportCaseEvent
  alias FastCheck.Support.SupportMessage

  @customer_exit_event_type "customer_exit"

  test "Ash metadata declares the direction- and event-scoped identities" do
    assert_identity(
      SupportMessage,
      :unique_operator_submission,
      [:provider_account_key, :client_submission_id]
    )

    assert_identity(
      SupportMessage,
      :unique_customer_wamid,
      [:provider_account_key, :provider_message_id]
    )

    assert_identity(
      SupportCaseEvent,
      :unique_customer_exit_wamid,
      [:provider_account_key, :provider_message_id]
    )

    assert_identity_index_name(
      SupportMessage,
      :unique_operator_submission,
      "support_messages_operator_submission_uidx"
    )

    assert_identity_index_name(
      SupportMessage,
      :unique_customer_wamid,
      "support_messages_customer_wamid_uidx"
    )

    assert_identity_index_name(
      SupportCaseEvent,
      :unique_customer_exit_wamid,
      "support_case_events_customer_exit_wamid_uidx"
    )

    assert_check_constraints(SupportMessage, [
      "support_messages_operator_identity_required",
      "support_messages_customer_identity_required"
    ])

    assert_check_constraints(SupportCaseEvent, [
      "support_case_events_customer_exit_identity_required"
    ])

    for resource <- [SupportMessage, SupportCaseEvent],
        attribute <- [:provider_account_key, :provider_message_id] do
      identity_attribute = ResourceInfo.attribute(resource, attribute)
      assert identity_attribute.sensitive?
      assert identity_attribute.allow_nil?
    end

    submission_attribute = ResourceInfo.attribute(SupportMessage, :client_submission_id)
    assert submission_attribute.sensitive?
    assert submission_attribute.allow_nil?
  end

  test "operator messages reject missing and blank account or submission identities" do
    case_id = insert_support_case!()

    for {account_key, submission_id} <- [
          {nil, "submission-1"},
          {"account-a", nil},
          {"   ", "submission-2"},
          {"account-a", " \t\n "}
        ] do
      assert_constraint(
        "support_messages_operator_identity_required",
        fn ->
          insert_message!(case_id, next_sequence!(), "operator",
            provider_account_key: account_key,
            client_submission_id: submission_id
          )
        end
      )
    end

    assert is_integer(
             insert_message!(case_id, next_sequence!(), "operator",
               provider_account_key: "account-a",
               client_submission_id: "submission-valid"
             )
           )
  end

  test "customer messages reject missing and blank account or WAMID identities" do
    case_id = insert_support_case!()

    for {account_key, provider_message_id} <- [
          {nil, "wamid-1"},
          {"account-a", nil},
          {" \t ", "wamid-2"},
          {"account-a", " \n "}
        ] do
      assert_constraint(
        "support_messages_customer_identity_required",
        fn ->
          insert_message!(case_id, next_sequence!(), "customer",
            provider_account_key: account_key,
            provider_message_id: provider_message_id
          )
        end
      )
    end

    assert is_integer(
             insert_message!(case_id, next_sequence!(), "customer",
               provider_account_key: "account-a",
               provider_message_id: "wamid-valid"
             )
           )
  end

  test "operator submissions and customer WAMIDs are unique within an account only" do
    case_id = insert_support_case!()

    insert_message!(case_id, next_sequence!(), "operator",
      provider_account_key: "account-a",
      client_submission_id: "submission-shared"
    )

    assert_raise Postgrex.Error, ~r/support_messages_operator_submission_uidx/, fn ->
      insert_message!(case_id, next_sequence!(), "operator",
        provider_account_key: "account-a",
        client_submission_id: "submission-shared"
      )
    end

    assert is_integer(
             insert_message!(case_id, next_sequence!(), "operator",
               provider_account_key: "account-b",
               client_submission_id: "submission-shared"
             )
           )

    insert_message!(case_id, next_sequence!(), "customer",
      provider_account_key: "account-a",
      provider_message_id: "wamid-shared"
    )

    assert_raise Postgrex.Error, ~r/support_messages_customer_wamid_uidx/, fn ->
      insert_message!(case_id, next_sequence!(), "customer",
        provider_account_key: "account-a",
        provider_message_id: "wamid-shared"
      )
    end

    assert is_integer(
             insert_message!(case_id, next_sequence!(), "customer",
               provider_account_key: "account-b",
               provider_message_id: "wamid-shared"
             )
           )
  end

  test "customer exit events require a receipt identity and are account scoped" do
    case_id = insert_support_case!()

    for {account_key, provider_message_id} <- [
          {nil, "wamid-exit-1"},
          {"account-a", nil},
          {"  ", "wamid-exit-2"},
          {"account-a", "\t "}
        ] do
      assert_constraint(
        "support_case_events_customer_exit_identity_required",
        fn ->
          insert_event!(case_id, next_sequence!(), @customer_exit_event_type,
            provider_account_key: account_key,
            provider_message_id: provider_message_id
          )
        end
      )
    end

    insert_event!(case_id, next_sequence!(), @customer_exit_event_type,
      provider_account_key: "account-a",
      provider_message_id: "wamid-exit-shared"
    )

    assert_raise Postgrex.Error, ~r/support_case_events_customer_exit_wamid_uidx/, fn ->
      insert_event!(case_id, next_sequence!(), @customer_exit_event_type,
        provider_account_key: "account-a",
        provider_message_id: "wamid-exit-shared"
      )
    end

    assert is_integer(
             insert_event!(case_id, next_sequence!(), @customer_exit_event_type,
               provider_account_key: "account-b",
               provider_message_id: "wamid-exit-shared"
             )
           )
  end

  test "unrelated audit events remain valid without provider receipt identities" do
    case_id = insert_support_case!()

    assert is_integer(insert_event!(case_id, 1, "operator_claimed"))
    assert is_integer(insert_event!(case_id, 2, "message_accepted"))
  end

  test "system messages may omit direction-specific provider identities" do
    case_id = insert_support_case!()

    assert is_integer(insert_message!(case_id, 1, "system", []))
  end

  test "separate PostgreSQL connections admit only one concurrent duplicate identity" do
    {conversation_id, case_id} = committed_support_case!()
    on_exit(fn -> delete_committed_support_case!(conversation_id, case_id) end)
    ciphertext = encrypted_fixture!()

    assert_one_concurrent_insert!(
      case_id,
      ciphertext,
      "operator",
      :client_submission_id,
      "submission-race",
      "support_messages_operator_submission_uidx",
      [1, 2]
    )

    assert_one_concurrent_insert!(
      case_id,
      ciphertext,
      "customer",
      :provider_message_id,
      "wamid-race",
      "support_messages_customer_wamid_uidx",
      [3, 4]
    )

    assert_one_concurrent_exit_event!(
      case_id,
      "wamid-exit-race",
      "support_case_events_customer_exit_wamid_uidx",
      [5, 6]
    )
  end

  defp assert_identity(resource, name, keys) do
    assert identity = Enum.find(ResourceInfo.identities(resource), &(&1.name == name))
    assert identity.keys == keys
    assert identity.where
  end

  defp assert_identity_index_name(resource, identity_name, expected_index_name) do
    assert PostgresInfo.identity_index_names(resource)[identity_name] == expected_index_name

    assert [[^expected_index_name]] =
             Repo.query!(
               """
               SELECT indexname
               FROM pg_indexes
               WHERE schemaname = current_schema() AND indexname = $1
               """,
               [expected_index_name]
             ).rows
  end

  defp assert_check_constraints(resource, names) do
    configured_names =
      resource
      |> PostgresInfo.check_constraints()
      |> MapSet.new(& &1.name)

    assert MapSet.subset?(MapSet.new(names), configured_names)
  end

  defp assert_constraint(name, fun) do
    assert_raise Postgrex.Error, Regex.compile!(Regex.escape(name)), fun
  end

  defp insert_conversation! do
    unique = System.unique_integer([:positive])
    phone = "+1555" <> String.pad_leading(Integer.to_string(unique), 7, "0")
    wa_id = "synthetic-support-#{unique}"

    [[id]] =
      Repo.query!(
        """
        INSERT INTO sales_conversations
          (phone_e164, wa_id, preferred_language, state, state_data, needs_human,
           inserted_at, updated_at)
        VALUES ($1, $2, 'en', 'main_menu', '{}', false, now(), now())
        RETURNING id
        """,
        [phone, wa_id]
      ).rows

    id
  end

  defp insert_support_case!(conversation_id \\ nil) do
    conversation_id = conversation_id || insert_conversation!()

    [[id]] =
      Repo.query!(
        """
        INSERT INTO support_cases
          (public_id, conversation_id, generation, state, requested_at,
           next_message_sequence, lock_version, inserted_at, updated_at)
        VALUES ($1, $2, 1, 'waiting', now(), 1, 1, now(), now())
        RETURNING id
        """,
        [Ecto.UUID.dump!(Ecto.UUID.generate()), conversation_id]
      ).rows

    id
  end

  defp next_sequence! do
    System.unique_integer([:positive])
  end

  defp insert_message!(case_id, sequence, direction, opts) do
    ciphertext = encrypted_fixture!()
    sender_operator_id = if direction == "operator", do: "synthetic-agent", else: nil

    [[id]] =
      Repo.query!(
        """
        INSERT INTO support_messages
          (support_case_id, sequence, direction, sender_operator_id,
           client_submission_id, provider_account_key, provider_message_id,
           body_ciphertext, body_key_version, accepted_at, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'test-v1', now(), now(), now())
        RETURNING id
        """,
        [
          case_id,
          sequence,
          direction,
          sender_operator_id,
          Keyword.get(opts, :client_submission_id),
          Keyword.get(opts, :provider_account_key),
          Keyword.get(opts, :provider_message_id),
          ciphertext
        ]
      ).rows

    id
  end

  defp insert_event!(case_id, sequence, event_type, opts \\ []) do
    [[id]] =
      Repo.query!(
        """
        INSERT INTO support_case_events
          (support_case_id, sequence, event_type, actor_type, actor_id,
           provider_account_key, provider_message_id, case_version, metadata, inserted_at)
        VALUES ($1, $2, $3, $4, 'synthetic-actor', $5, $6, 1, '{}', now())
        RETURNING id
        """,
        [
          case_id,
          sequence,
          event_type,
          if(event_type == @customer_exit_event_type, do: "customer", else: "operator"),
          Keyword.get(opts, :provider_account_key),
          Keyword.get(opts, :provider_message_id)
        ]
      ).rows

    id
  end

  defp assert_one_concurrent_exit_event!(
         case_id,
         provider_message_id,
         expected_constraint,
         sequences
       ) do
    parent = self()

    tasks =
      Enum.map(sequences, fn sequence ->
        Task.async(fn ->
          concurrent_exit_event_insert(parent, case_id, sequence, provider_message_id)
        end)
      end)

    ready =
      for _ <- tasks do
        assert_receive {:exit_event_insert_ready, pid, backend_pid}, 5_000
        {pid, backend_pid}
      end

    assert length(Enum.uniq_by(ready, &elem(&1, 0))) == 2
    assert length(Enum.uniq_by(ready, &elem(&1, 1))) == 2
    Enum.each(ready, fn {pid, _backend_pid} -> send(pid, :insert_identity) end)

    results = Task.await_many(tasks, 10_000)
    assert Enum.count(results, &(&1 == :inserted)) == 1
    assert Enum.count(results, &(&1 == {:duplicate, expected_constraint})) == 1

    [[count]] =
      Sandbox.unboxed_run(Repo, fn ->
        Repo.query!(
          """
          SELECT count(*)
          FROM support_case_events
          WHERE event_type = 'customer_exit'
            AND provider_account_key = 'account-race'
            AND provider_message_id = $1
          """,
          [provider_message_id]
        ).rows
      end)

    assert count == 1
  end

  defp concurrent_exit_event_insert(parent, case_id, sequence, provider_message_id) do
    Sandbox.unboxed_run(Repo, fn ->
      [[backend_pid]] = Repo.query!("SELECT pg_backend_pid()", []).rows
      send(parent, {:exit_event_insert_ready, self(), backend_pid})
      await_identity_insert_start!()

      insert_exit_event_with_duplicate_result(case_id, sequence, provider_message_id)
    end)
  end

  defp insert_exit_event_with_duplicate_result(case_id, sequence, provider_message_id) do
    Repo.query!(
      """
      INSERT INTO support_case_events
        (support_case_id, sequence, event_type, actor_type, actor_id,
         provider_account_key, provider_message_id, case_version, metadata, inserted_at)
      VALUES ($1, $2, 'customer_exit', 'customer', 'synthetic-customer',
              'account-race', $3, 1, '{}', now())
      """,
      [case_id, sequence, provider_message_id]
    )

    :inserted
  rescue
    error in Postgrex.Error ->
      if error.postgres.code == :unique_violation do
        {:duplicate, error.postgres.constraint}
      else
        reraise error, __STACKTRACE__
      end
  end

  defp encrypted_fixture! do
    {:ok, ciphertext} = Crypto.encrypt("synthetic encrypted support fixture")
    ciphertext
  end

  defp committed_support_case! do
    Sandbox.unboxed_run(Repo, fn ->
      conversation_id = insert_conversation!()
      case_id = insert_support_case!(conversation_id)
      {conversation_id, case_id}
    end)
  end

  defp delete_committed_support_case!(conversation_id, case_id) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.query!("DELETE FROM support_messages WHERE support_case_id = $1", [case_id])
      Repo.query!("DELETE FROM support_case_events WHERE support_case_id = $1", [case_id])
      Repo.query!("DELETE FROM support_cases WHERE id = $1", [case_id])
      Repo.query!("DELETE FROM sales_conversations WHERE id = $1", [conversation_id])
    end)
  end

  defp assert_one_concurrent_insert!(
         case_id,
         ciphertext,
         direction,
         identity_field,
         identity_value,
         expected_constraint,
         sequences
       ) do
    parent = self()

    tasks =
      Enum.map(sequences, fn sequence ->
        Task.async(fn ->
          concurrent_identity_insert(
            parent,
            case_id,
            sequence,
            direction,
            identity_field,
            identity_value,
            ciphertext
          )
        end)
      end)

    ready =
      for _ <- tasks do
        assert_receive {:identity_insert_ready, pid, backend_pid}, 5_000
        {pid, backend_pid}
      end

    assert length(Enum.uniq_by(ready, &elem(&1, 0))) == 2
    assert length(Enum.uniq_by(ready, &elem(&1, 1))) == 2
    Enum.each(ready, fn {pid, _backend_pid} -> send(pid, :insert_identity) end)

    results = Task.await_many(tasks, 10_000)
    assert Enum.count(results, &(&1 == :inserted)) == 1
    assert Enum.count(results, &(&1 == {:duplicate, expected_constraint})) == 1

    field_name = Atom.to_string(identity_field)

    [[count]] =
      Sandbox.unboxed_run(Repo, fn ->
        Repo.query!(
          """
          SELECT count(*)
          FROM support_messages
          WHERE direction = $1
            AND provider_account_key = 'account-race'
            AND #{field_name} = $2
          """,
          [direction, identity_value]
        ).rows
      end)

    assert count == 1
  end

  defp concurrent_identity_insert(
         parent,
         case_id,
         sequence,
         direction,
         identity_field,
         identity_value,
         ciphertext
       ) do
    Sandbox.unboxed_run(Repo, fn ->
      [[backend_pid]] = Repo.query!("SELECT pg_backend_pid()", []).rows
      send(parent, {:identity_insert_ready, self(), backend_pid})
      await_identity_insert_start!()

      insert_with_duplicate_result(
        case_id,
        sequence,
        direction,
        identity_field,
        identity_value,
        ciphertext
      )
    end)
  end

  defp await_identity_insert_start! do
    receive do
      :insert_identity -> :ok
    after
      5_000 -> raise "identity insert barrier timed out"
    end
  end

  defp insert_with_duplicate_result(
         case_id,
         sequence,
         direction,
         identity_field,
         identity_value,
         ciphertext
       ) do
    insert_message_on_connection!(
      case_id,
      sequence,
      direction,
      identity_field,
      identity_value,
      "account-race",
      ciphertext
    )

    :inserted
  rescue
    error in Postgrex.Error ->
      if error.postgres.code == :unique_violation do
        {:duplicate, error.postgres.constraint}
      else
        reraise error, __STACKTRACE__
      end
  end

  defp insert_message_on_connection!(
         case_id,
         sequence,
         direction,
         identity_field,
         identity_value,
         account_key,
         ciphertext
       ) do
    {client_submission_id, provider_message_id} =
      case identity_field do
        :client_submission_id -> {identity_value, nil}
        :provider_message_id -> {nil, identity_value}
      end

    Repo.query!(
      """
      INSERT INTO support_messages
        (support_case_id, sequence, direction, sender_operator_id,
         client_submission_id, provider_account_key, provider_message_id,
         body_ciphertext, body_key_version, accepted_at, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'test-v1', now(), now(), now())
      """,
      [
        case_id,
        sequence,
        direction,
        if(direction == "operator", do: "synthetic-agent", else: nil),
        client_submission_id,
        account_key,
        provider_message_id,
        ciphertext
      ]
    )
  end
end
