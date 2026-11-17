defmodule FastCheck.Support.SupportCaseAuthorizationTest do
  use FastCheck.DataCase, async: false

  alias Ash.Changeset
  alias FastCheck.Operations.GlobalAccess
  alias FastCheck.Repo
  alias FastCheck.Support.SupportCase
  alias Plug.Conn
  alias Plug.Test, as: PlugTest

  @operator "support-agent"
  @account_key "synthetic-support-account"

  setup do
    previous_dashboard_auth = Application.get_env(:fastcheck, :dashboard_auth)
    previous_global_access = Application.get_env(:fastcheck, :operations_global_access)
    previous_account = Application.get_env(:fastcheck, :whatsapp_business_account_id)
    previous_phone = Application.get_env(:fastcheck, :whatsapp_phone_number_id)

    Application.put_env(:fastcheck, :dashboard_auth, %{
      username: @operator,
      password: "synthetic-test-password"
    })

    Application.put_env(:fastcheck, :operations_global_access,
      allowed_usernames: [@operator, "other-agent"]
    )

    Application.put_env(:fastcheck, :whatsapp_business_account_id, @account_key)
    Application.put_env(:fastcheck, :whatsapp_phone_number_id, "synthetic-support-phone")

    on_exit(fn ->
      restore_env(:dashboard_auth, previous_dashboard_auth)
      restore_env(:operations_global_access, previous_global_access)
      restore_env(:whatsapp_business_account_id, previous_account)
      restore_env(:whatsapp_phone_number_id, previous_phone)
    end)

    :ok
  end

  test "Global Ops actions require the current server-verified identity context" do
    support_case = create_case!()
    verified_operator = operator_conn(@operator)

    assert GlobalAccess.authorized_identity?(verified_operator)

    assert {:error, _} =
             transition(support_case, :claim, @operator, %{expected_lock_version: 1})

    assert {:error, _} =
             transition(support_case, :claim, %{username: @operator}, %{
               expected_lock_version: 1
             })

    assert case_state(support_case.id) == {"waiting", 1, nil}

    assert {:ok, claimed} =
             transition(support_case, :claim, verified_operator, %{expected_lock_version: 1})

    unverified_conn =
      PlugTest.conn(:get, "/") |> Conn.assign(:current_user, %{username: @operator})

    forged_map = %{actor_type: :admin, username: @operator, id: @operator}

    assert {:error, _} =
             transition(claimed, :release, unverified_conn, %{expected_lock_version: 2})

    assert {:error, _} = transition(claimed, :release, @operator, %{expected_lock_version: 2})
    assert {:error, _} = transition(claimed, :release, forged_map, %{expected_lock_version: 2})
    assert case_state(claimed.id) == {"claimed", 2, @operator}
  end

  test "operator authority is revalidated after the identity is revoked" do
    support_case = create_case!()
    operator = operator_conn(@operator)

    assert {:ok, claimed} =
             transition(support_case, :claim, operator, %{expected_lock_version: 1})

    Application.put_env(:fastcheck, :operations_global_access, allowed_usernames: ["other-agent"])

    assert {:error, _} =
             transition(claimed, :release, operator, %{expected_lock_version: 2})

    assert case_state(claimed.id) == {"claimed", 2, @operator}
  end

  test "a release requires the currently verified assignee" do
    support_case = create_case!()
    claimant = operator_conn(@operator)
    other_operator = operator_conn("other-agent")

    assert {:ok, claimed} =
             transition(support_case, :claim, claimant, %{expected_lock_version: 1})

    assert {:error, _} =
             transition(claimed, :release, other_operator, %{expected_lock_version: 2})

    assert case_state(claimed.id) == {"claimed", 2, @operator}
  end

  test "verified customer exit is scoped to the current WhatsApp account and conversation" do
    support_case = create_case!()
    wa_id = conversation_wa_id(support_case)

    wrong_account = system_actor(:customer_exit, wa_id, "other-account", "wamid-exit-a")
    wrong_customer = system_actor(:customer_exit, "another-wa-id", @account_key, "wamid-exit-b")
    no_verified_context = PlugTest.conn(:post, "/")

    assert {:error, _} =
             transition(support_case, :customer_cancel, wrong_account, %{expected_lock_version: 1})

    assert {:error, _} =
             transition(support_case, :customer_cancel, wrong_customer, %{
               expected_lock_version: 1
             })

    assert {:error, _} =
             transition(support_case, :customer_cancel, no_verified_context, %{
               expected_lock_version: 1
             })

    assert case_state(support_case.id) == {"waiting", 1, nil}
    assert length(events(support_case.id)) == 1
  end

  test "the intake action rejects actor maps and a channel identity from another account" do
    conversation = insert_conversation!()
    forged_actor = %{actor_type: :system, actor_id: "support_intake", wa_id: conversation.wa_id}
    wrong_account = system_actor(:intake, conversation.wa_id, "another-account", nil)

    assert {:error, _} = create_waiting(conversation.id, forged_actor)
    assert {:error, _} = create_waiting(conversation.id, @account_key)
    assert {:error, _} = create_waiting(conversation.id, wrong_account)

    assert [[0]] =
             Repo.query!("SELECT count(*) FROM support_cases WHERE conversation_id = $1", [
               conversation.id
             ]).rows
  end

  test "a prior terminal case cannot be reopened as another intake generation" do
    support_case = create_case!()

    customer_exit =
      system_actor(
        :customer_exit,
        conversation_wa_id(support_case),
        @account_key,
        "wamid-terminal"
      )

    assert {:ok, cancelled} =
             transition(support_case, :customer_cancel, customer_exit, %{expected_lock_version: 1})

    intake = system_actor(:intake, conversation_wa_id(cancelled), @account_key, nil)

    assert {:error, _} = create_waiting(cancelled.conversation_id, intake)
    assert case_state(cancelled.id) == {"cancelled", 2, nil}
    assert length(events(cancelled.id)) == 2
  end

  defp create_case! do
    conversation = insert_conversation!()
    actor = system_actor(:intake, conversation.wa_id, @account_key, nil)
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

  defp case_state(case_id) do
    [[state, version, assigned]] =
      Repo.query!(
        "SELECT state, lock_version, assigned_operator_id FROM support_cases WHERE id = $1",
        [case_id]
      ).rows

    {state, version, assigned}
  end

  defp events(case_id) do
    Repo.query!("SELECT event_type FROM support_case_events WHERE support_case_id = $1", [case_id]).rows
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

  defp conversation_wa_id(%{conversation_id: conversation_id}) do
    [[wa_id]] =
      Repo.query!("SELECT wa_id FROM sales_conversations WHERE id = $1", [conversation_id]).rows

    wa_id
  end

  defp operator_conn(username) do
    PlugTest.conn(:get, "/")
    |> PlugTest.init_test_session(%{dashboard_username: username})
    |> Conn.assign(:current_user, %{id: username, username: username})
  end

  defp system_actor(kind, wa_id, provider_account_key, provider_message_id) do
    context = %{
      kind: kind,
      wa_id: wa_id,
      provider_account_key: provider_account_key,
      provider_message_id: provider_message_id
    }

    PlugTest.conn(:post, "/")
    |> Conn.put_private(:fastcheck_verified_support_actor, context)
  end

  defp restore_env(key, nil), do: Application.delete_env(:fastcheck, key)
  defp restore_env(key, value), do: Application.put_env(:fastcheck, key, value)
end
