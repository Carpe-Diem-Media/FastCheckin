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

  test "does not expose implicit CRUD actions before guarded actions are implemented" do
    for resource <- @resources do
      mutating_actions =
        resource
        |> ResourceInfo.actions()
        |> Enum.filter(&(&1.type in [:create, :update, :destroy]))

      assert mutating_actions == [],
             "#{inspect(resource)} must not expose unguarded mutation actions"
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
