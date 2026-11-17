defmodule FastCheck.Support.SupportDomainTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info, as: ResourceInfo
  alias AshPostgres.DataLayer

  alias FastCheck.Sales.Conversation
  alias FastCheck.Support
  alias FastCheck.Support.ConversationClosure
  alias FastCheck.Support.ExternalCreateOperation
  alias FastCheck.Support.SupportCase
  alias FastCheck.Support.SupportCaseEvent
  alias FastCheck.Support.SupportMessage

  @resources [
    SupportCase,
    SupportMessage,
    ExternalCreateOperation,
    ConversationClosure,
    SupportCaseEvent
  ]

  test "registers the five canonical support resources in one domain" do
    assert MapSet.new(Ash.Domain.Info.resources(Support)) == MapSet.new(@resources)

    for resource <- @resources do
      assert Code.ensure_loaded?(resource)
      assert ResourceInfo.data_layer(resource) == DataLayer
    end
  end

  test "keeps Sales.Conversation as the parent and assignment on SupportCase" do
    assert_relationship(SupportCase, :conversation, :belongs_to, Conversation)
    assert_relationship(SupportCase, :messages, :has_many, SupportMessage)
    assert_relationship(SupportCase, :operations, :has_many, ExternalCreateOperation)
    assert_relationship(SupportCase, :closures, :has_many, ConversationClosure)
    assert_relationship(SupportCase, :events, :has_many, SupportCaseEvent)

    assert ResourceInfo.attribute(SupportCase, :assigned_operator_id)
    refute ResourceInfo.attribute(SupportCase, :support_handoff_id)
    refute ResourceInfo.attribute(SupportCase, :bridge_message_id)
  end

  test "exposes the adopted case identity, reason, and lifecycle timestamps" do
    assert %{type: Ash.Type.UUID, allow_nil?: false} =
             ResourceInfo.attribute(SupportCase, :public_id)

    assert Enum.any?(ResourceInfo.identities(SupportCase), fn identity ->
             identity.name == :unique_public_id and identity.keys == [:public_id]
           end)

    assert reason_code = ResourceInfo.attribute(SupportCase, :reason_code)
    assert reason_code.type == Ash.Type.String
    assert reason_code.constraints[:max_length] == 64

    assert ResourceInfo.attribute(SupportCase, :resolved_at)
    assert ResourceInfo.attribute(SupportCase, :cancelled_at)
  end

  test "exposes explicit operation dispatch timestamps and bounded response classification" do
    for name <- [:dispatch_authorized_at, :dispatch_started_at, :response_received_at] do
      assert ResourceInfo.attribute(ExternalCreateOperation, name)
    end

    assert response_class = ResourceInfo.attribute(ExternalCreateOperation, :response_class)
    assert response_class.type == Ash.Type.String
    assert response_class.constraints[:max_length] == 64

    assert failure_class = ResourceInfo.attribute(ExternalCreateOperation, :failure_class)
    assert failure_class.type == Ash.Type.String
    assert failure_class.constraints[:max_length] == 64
  end

  test "exposes only the approved private lifecycle mutation actions" do
    expected_mutations = %{
      SupportCase => [:create_waiting, :claim, :release, :customer_cancel],
      SupportCaseEvent => []
    }

    for resource <- @resources do
      mutating_actions =
        resource
        |> ResourceInfo.actions()
        |> Enum.filter(&(&1.type in [:create, :update, :destroy]))
        |> Enum.map(& &1.name)

      assert mutating_actions == Map.get(expected_mutations, resource, []),
             "#{inspect(resource)} exposes an unapproved lifecycle mutation"
    end
  end

  test "stores transcript content only as sensitive ciphertext" do
    assert %{sensitive?: true, allow_nil?: false} =
             ResourceInfo.attribute(SupportMessage, :body_ciphertext)

    assert ResourceInfo.attribute(SupportMessage, :body_key_version)

    attributes =
      SupportMessage
      |> ResourceInfo.attributes()
      |> MapSet.new(& &1.name)

    refute Enum.any?([:body, :message_body, :plaintext, :phone_e164, :wa_id], &(&1 in attributes))
  end

  defp assert_relationship(resource, name, type, destination) do
    assert relationship = ResourceInfo.relationship(resource, name)
    assert relationship.type == type
    assert relationship.destination == destination
  end
end
