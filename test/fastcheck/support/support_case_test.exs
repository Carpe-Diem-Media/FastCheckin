defmodule FastCheck.Support.SupportCaseTest do
  use FastCheck.DataCase, async: false

  alias FastCheck.Crypto
  alias FastCheck.Repo

  @support_tables [
    "conversation_closures",
    "external_create_operations",
    "support_case_events",
    "support_cases",
    "support_messages"
  ]

  test "creates the five support workspace tables" do
    tables =
      Repo.query!(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name IN (
            'conversation_closures',
            'external_create_operations',
            'support_case_events',
            'support_cases',
            'support_messages'
          )
        ORDER BY table_name
        """,
        []
      ).rows
      |> List.flatten()

    assert tables == @support_tables
  end

  test "creates the bounded lookup and uniqueness indexes" do
    indexes =
      Repo.query!(
        """
        SELECT indexname
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename IN (
            'support_cases',
            'support_messages',
            'external_create_operations',
            'conversation_closures',
            'support_case_events'
          )
        """,
        []
      ).rows
      |> List.flatten()
      |> MapSet.new()

    assert MapSet.subset?(
             MapSet.new([
               "support_cases_conversation_generation_uidx",
               "support_cases_public_id_uidx",
               "support_cases_one_active_per_conversation_uidx",
               "support_cases_queue_idx",
               "support_cases_assignment_idx",
               "support_messages_case_sequence_uidx",
               "support_messages_case_sequence_desc_idx",
               "support_messages_id_case_uidx",
               "external_create_operations_operation_id_uidx",
               "external_create_operations_message_provider_kind_uidx",
               "external_create_operations_id_case_uidx",
               "external_create_operations_due_work_idx",
               "conversation_closures_case_epoch_uidx",
               "conversation_closures_id_case_uidx",
               "conversation_closures_one_active_per_case_uidx",
               "conversation_closures_case_state_idx",
               "support_case_events_case_sequence_uidx"
             ]),
             indexes
           )
  end

  test "creates the adopted case and operation columns with database-enforced bounds" do
    case_columns =
      Repo.query!(
        """
        SELECT column_name, data_type, is_nullable, character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'support_cases'
        """,
        []
      ).rows
      |> Map.new(fn [name, type, nullable, max_length] ->
        {name, {type, nullable, max_length}}
      end)

    assert case_columns["public_id"] == {"uuid", "NO", nil}
    assert case_columns["reason_code"] == {"character varying", "YES", 64}
    assert case_columns["resolved_at"] == {"timestamp without time zone", "YES", nil}
    assert case_columns["cancelled_at"] == {"timestamp without time zone", "YES", nil}

    operation_columns =
      Repo.query!(
        """
        SELECT column_name, data_type, is_nullable, character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'external_create_operations'
        """,
        []
      ).rows
      |> Map.new(fn [name, type, nullable, max_length] ->
        {name, {type, nullable, max_length}}
      end)

    for name <- ["dispatch_authorized_at", "dispatch_started_at", "response_received_at"] do
      assert operation_columns[name] == {"timestamp without time zone", "YES", nil}
    end

    assert operation_columns["response_class"] == {"character varying", "YES", 64}
    assert operation_columns["failure_class"] == {"character varying", "YES", 64}
  end

  test "enforces public id uniqueness and classification bounds in PostgreSQL" do
    public_id = Ecto.UUID.generate()
    first_conversation_id = insert_conversation!()
    insert_support_case!(first_conversation_id, 1, "waiting", public_id: public_id)

    second_conversation_id = insert_conversation!()

    assert_raise Postgrex.Error, ~r/null value in column "public_id"/, fn ->
      Repo.query!(
        """
        INSERT INTO support_cases
          (public_id, conversation_id, generation, state, requested_at, inserted_at, updated_at)
        VALUES (NULL, $1, 1, 'waiting', now(), now(), now())
        """,
        [second_conversation_id]
      )
    end

    assert_raise Postgrex.Error, fn ->
      insert_support_case!(second_conversation_id, 1, "waiting", public_id: public_id)
    end

    third_conversation_id = insert_conversation!()

    assert_raise Postgrex.Error, ~r/value too long for type character varying\(64\)/, fn ->
      insert_support_case!(third_conversation_id, 1, "waiting",
        reason_code: String.duplicate("r", 65)
      )
    end

    case_id = insert_support_case!(third_conversation_id, 1, "waiting")
    message_id = insert_message!(case_id, 1)

    assert_raise Postgrex.Error, ~r/value too long for type character varying\(64\)/, fn ->
      insert_operation!(case_id, message_id, "00000000-0000-7000-8000-000000000021",
        response_class: String.duplicate("c", 65)
      )
    end

    assert_raise Postgrex.Error, ~r/value too long for type character varying\(64\)/, fn ->
      insert_operation!(case_id, message_id, "00000000-0000-7000-8000-000000000022",
        failure_class: String.duplicate("f", 65)
      )
    end
  end

  test "all support foreign keys preserve dependent and audit rows" do
    delete_rules =
      Repo.query!(
        """
        SELECT rc.delete_rule
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.referential_constraints AS rc
          ON tc.constraint_name = rc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_name IN (
            'support_cases',
            'support_messages',
            'external_create_operations',
            'conversation_closures',
            'support_case_events'
          )
        """,
        []
      ).rows
      |> List.flatten()

    assert delete_rules != []
    assert Enum.all?(delete_rules, &(&1 == "RESTRICT"))
  end

  test "operation and audit references cannot cross support case boundaries" do
    first_conversation_id = insert_conversation!()
    first_case_id = insert_support_case!(first_conversation_id, 1, "waiting")
    first_message_id = insert_message!(first_case_id, 1)

    first_operation_id =
      insert_operation!(first_case_id, first_message_id, "00000000-0000-7000-8000-000000000011")

    second_conversation_id = insert_conversation!()
    second_case_id = insert_support_case!(second_conversation_id, 1, "waiting")

    assert_raise Postgrex.Error, fn ->
      Repo.query!(
        """
        INSERT INTO external_create_operations
          (operation_id, support_case_id, support_message_id, provider, operation_kind, state,
           attempt_number, fencing_version, lock_version, inserted_at, updated_at)
        VALUES ('00000000-0000-7000-8000-000000000012', $1, $2, 'whatsapp', 'send_message',
                'queued', 0, 0, 1, now(), now())
        """,
        [second_case_id, first_message_id]
      )
    end

    insert_closure!(first_case_id, 1, "resolved")

    [[closure_id]] =
      Repo.query!("SELECT id FROM conversation_closures WHERE support_case_id = $1", [
        first_case_id
      ]).rows

    assert_raise Postgrex.Error, fn ->
      Repo.query!(
        """
        INSERT INTO support_case_events
          (support_case_id, sequence, event_type, actor_type, actor_id, support_message_id,
           external_create_operation_id, conversation_closure_id, case_version, metadata, inserted_at)
        VALUES ($1, 1, 'message_accepted', 'system', 'synthetic-test', $2, $3, $4, 1, '{}', now())
        """,
        [second_case_id, first_message_id, first_operation_id, closure_id]
      )
    end
  end

  test "support cases retain a restrictive Sales conversation foreign key" do
    assert_foreign_key("support_cases", "conversation_id", "sales_conversations")
    assert_foreign_key_delete_rule("support_cases", "conversation_id", "RESTRICT")

    conversation_id = insert_conversation!()
    insert_support_case!(conversation_id, 1, "waiting")

    assert_raise Postgrex.Error, fn ->
      Repo.query!("DELETE FROM sales_conversations WHERE id = $1", [conversation_id])
    end
  end

  test "support case state, generation, sequence, and lock version have database guards" do
    conversation_id = insert_conversation!()

    assert_raise Postgrex.Error, ~r/support_cases_state_valid/, fn ->
      insert_support_case!(conversation_id, 1, "not_a_state")
    end

    assert_raise Postgrex.Error, ~r/support_cases_generation_positive/, fn ->
      insert_support_case!(conversation_id, 0, "waiting")
    end

    assert_raise Postgrex.Error, ~r/support_cases_next_message_sequence_positive/, fn ->
      Repo.query!(
        """
        INSERT INTO support_cases
          (public_id, conversation_id, generation, state, requested_at, next_message_sequence,
           lock_version, inserted_at, updated_at)
        VALUES ($1, $2, 1, 'waiting', now(), 0, 1, now(), now())
        """,
        [Ecto.UUID.dump!(Ecto.UUID.generate()), conversation_id]
      )
    end

    assert_raise Postgrex.Error, ~r/support_cases_lock_version_positive/, fn ->
      Repo.query!(
        """
        INSERT INTO support_cases
          (public_id, conversation_id, generation, state, requested_at, next_message_sequence,
           lock_version, inserted_at, updated_at)
        VALUES ($1, $2, 1, 'waiting', now(), 1, 0, now(), now())
        """,
        [Ecto.UUID.dump!(Ecto.UUID.generate()), conversation_id]
      )
    end
  end

  test "enforces generation, active-case, message-sequence, operation, closure, and event uniqueness" do
    conversation_id = insert_conversation!()
    case_id = insert_support_case!(conversation_id, 1, "waiting")

    assert_raise Postgrex.Error, fn ->
      insert_support_case!(conversation_id, 1, "resolved")
    end

    assert_raise Postgrex.Error, fn ->
      insert_support_case!(conversation_id, 2, "claimed")
    end

    message_id = insert_message!(case_id, 1)

    assert_raise Postgrex.Error, fn ->
      insert_message!(case_id, 1)
    end

    operation_id = insert_operation!(case_id, message_id, "00000000-0000-7000-8000-000000000001")

    assert_raise Postgrex.Error, fn ->
      insert_operation!(case_id, message_id, "00000000-0000-7000-8000-000000000002")
    end

    second_message_id = insert_message!(case_id, 2)

    assert_raise Postgrex.Error, fn ->
      insert_operation!(case_id, second_message_id, "00000000-0000-7000-8000-000000000001")
    end

    insert_closure!(case_id, 1, "requested")

    assert_raise Postgrex.Error, fn ->
      insert_closure!(case_id, 1, "aborted")
    end

    assert_raise Postgrex.Error, fn ->
      insert_closure!(case_id, 2, "reconciling")
    end

    insert_event!(case_id, 1, operation_id)

    assert_raise Postgrex.Error, fn ->
      insert_event!(case_id, 1, operation_id)
    end
  end

  test "rejects unsupported states for closure and operation records" do
    conversation_id = insert_conversation!()
    case_id = insert_support_case!(conversation_id, 1, "waiting")
    message_id = insert_message!(case_id, 1)

    assert_raise Postgrex.Error, ~r/external_create_operations_state_valid/, fn ->
      Repo.query!(
        """
        INSERT INTO external_create_operations
          (operation_id, support_case_id, support_message_id, provider, operation_kind, state,
           attempt_number, fencing_version, lock_version, inserted_at, updated_at)
        VALUES ('00000000-0000-7000-8000-000000000003', $1, $2, 'whatsapp', 'send_message',
                'not_a_state', 0, 0, 1, now(), now())
        """,
        [case_id, message_id]
      )
    end

    assert_raise Postgrex.Error, ~r/conversation_closures_state_valid/, fn ->
      Repo.query!(
        """
        INSERT INTO conversation_closures
          (support_case_id, closure_epoch, state, case_version, requested_at, inserted_at, updated_at)
        VALUES ($1, 1, 'not_a_state', 1, now(), now(), now())
        """,
        [case_id]
      )
    end
  end

  test "rejects invalid message, UUIDv7, closure epoch, and audit sequence values" do
    conversation_id = insert_conversation!()
    case_id = insert_support_case!(conversation_id, 1, "waiting")
    {:ok, encrypted_body} = Crypto.encrypt("synthetic support fixture")

    assert_raise Postgrex.Error, ~r/support_messages_sequence_positive/, fn ->
      Repo.query!(
        """
        INSERT INTO support_messages
          (support_case_id, sequence, direction, body_ciphertext, body_key_version, accepted_at,
           inserted_at, updated_at)
        VALUES ($1, 0, 'customer', $2, 'test-v1', now(), now(), now())
        """,
        [case_id, encrypted_body]
      )
    end

    assert_raise Postgrex.Error, ~r/support_messages_direction_valid/, fn ->
      Repo.query!(
        """
        INSERT INTO support_messages
          (support_case_id, sequence, direction, body_ciphertext, body_key_version, accepted_at,
           inserted_at, updated_at)
        VALUES ($1, 1, 'unknown', $2, 'test-v1', now(), now(), now())
        """,
        [case_id, encrypted_body]
      )
    end

    message_id = insert_message!(case_id, 1)

    assert_raise Postgrex.Error, ~r/external_create_operations_uuid_v7/, fn ->
      Repo.query!(
        """
        INSERT INTO external_create_operations
          (operation_id, support_case_id, support_message_id, provider, operation_kind, state,
           attempt_number, fencing_version, lock_version, inserted_at, updated_at)
        VALUES ('00000000-0000-4000-8000-000000000001', $1, $2, 'whatsapp', 'send_message',
                'queued', 0, 0, 1, now(), now())
        """,
        [case_id, message_id]
      )
    end

    assert_raise Postgrex.Error, ~r/conversation_closures_epoch_positive/, fn ->
      Repo.query!(
        """
        INSERT INTO conversation_closures
          (support_case_id, closure_epoch, state, case_version, requested_at, inserted_at, updated_at)
        VALUES ($1, 0, 'aborted', 1, now(), now(), now())
        """,
        [case_id]
      )
    end

    assert_raise Postgrex.Error, ~r/support_case_events_sequence_positive/, fn ->
      Repo.query!(
        """
        INSERT INTO support_case_events
          (support_case_id, sequence, event_type, actor_type, actor_id, case_version, metadata, inserted_at)
        VALUES ($1, 0, 'test', 'system', 'synthetic-test', 1, '{}', now())
        """,
        [case_id]
      )
    end
  end

  defp insert_conversation! do
    result =
      Repo.query!(
        """
        INSERT INTO sales_conversations
          (phone_e164, wa_id, preferred_language, state, state_data, needs_human, inserted_at, updated_at)
        VALUES ('+15555550100', $1, 'en', 'main_menu', '{}', false, now(), now())
        RETURNING id
        """,
        ["synthetic-#{System.unique_integer([:positive])}"]
      )

    [[id]] = result.rows
    id
  end

  defp insert_support_case!(conversation_id, generation, state, opts \\ []) do
    public_id = Keyword.get(opts, :public_id, Ecto.UUID.generate())
    reason_code = Keyword.get(opts, :reason_code)

    result =
      Repo.query!(
        """
        INSERT INTO support_cases
          (public_id, conversation_id, generation, state, reason_code, requested_at,
           next_message_sequence, lock_version, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, now(), 1, 1, now(), now())
        RETURNING id
        """,
        [Ecto.UUID.dump!(public_id), conversation_id, generation, state, reason_code]
      )

    [[id]] = result.rows
    id
  end

  defp insert_message!(case_id, sequence) do
    {:ok, encrypted_body} = Crypto.encrypt("synthetic support fixture")

    result =
      Repo.query!(
        """
        INSERT INTO support_messages
          (support_case_id, sequence, direction, body_ciphertext, body_key_version, accepted_at,
           inserted_at, updated_at)
        VALUES ($1, $2, 'customer', $3, 'test-v1', now(), now(), now())
        RETURNING id
        """,
        [case_id, sequence, encrypted_body]
      )

    [[id]] = result.rows
    id
  end

  defp insert_operation!(case_id, message_id, operation_id, opts \\ []) do
    response_class = Keyword.get(opts, :response_class)
    failure_class = Keyword.get(opts, :failure_class)

    result =
      Repo.query!(
        """
        INSERT INTO external_create_operations
          (operation_id, support_case_id, support_message_id, provider, operation_kind, state,
           response_class, failure_class, attempt_number, fencing_version, lock_version,
           inserted_at, updated_at)
        VALUES ($1, $2, $3, 'whatsapp', 'send_message', 'queued', $4, $5, 0, 0, 1, now(), now())
        RETURNING id
        """,
        [Ecto.UUID.dump!(operation_id), case_id, message_id, response_class, failure_class]
      )

    [[id]] = result.rows
    id
  end

  defp insert_closure!(case_id, epoch, state) do
    Repo.query!(
      """
      INSERT INTO conversation_closures
        (support_case_id, closure_epoch, state, case_version, requested_at, inserted_at, updated_at)
      VALUES ($1, $2, $3, 1, now(), now(), now())
      """,
      [case_id, epoch, state]
    )
  end

  defp insert_event!(case_id, sequence, operation_id) do
    Repo.query!(
      """
      INSERT INTO support_case_events
        (support_case_id, sequence, event_type, actor_type, actor_id,
         external_create_operation_id, case_version, metadata, inserted_at)
      VALUES ($1, $2, 'message_accepted', 'system', 'test', $3, 1, '{}', now())
      """,
      [case_id, sequence, operation_id]
    )
  end

  defp assert_foreign_key(table_name, column_name, foreign_table_name) do
    assert [[^table_name, ^column_name, ^foreign_table_name]] =
             Repo.query!(
               """
               SELECT tc.table_name, kcu.column_name, ccu.table_name
               FROM information_schema.table_constraints AS tc
               JOIN information_schema.key_column_usage AS kcu
                 ON tc.constraint_name = kcu.constraint_name
               JOIN information_schema.constraint_column_usage AS ccu
                 ON ccu.constraint_name = tc.constraint_name
               WHERE tc.constraint_type = 'FOREIGN KEY'
                 AND tc.table_name = $1
                 AND kcu.column_name = $2
                 AND ccu.table_name = $3
               """,
               [table_name, column_name, foreign_table_name]
             ).rows
  end

  defp assert_foreign_key_delete_rule(table_name, column_name, delete_rule) do
    assert [[^delete_rule]] =
             Repo.query!(
               """
               SELECT rc.delete_rule
               FROM information_schema.referential_constraints AS rc
               JOIN information_schema.key_column_usage AS kcu
                 ON rc.constraint_name = kcu.constraint_name
               WHERE kcu.table_name = $1
                 AND kcu.column_name = $2
               """,
               [table_name, column_name]
             ).rows
  end
end
