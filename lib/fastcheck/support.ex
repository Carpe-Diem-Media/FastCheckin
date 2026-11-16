defmodule FastCheck.Support do
  @moduledoc """
  Ash domain for FastCheck-owned customer support cases and their durable history.
  """

  use Ash.Domain, otp_app: :fastcheck

  resources do
    resource(FastCheck.Support.SupportCase)
    resource(FastCheck.Support.SupportMessage)
    resource(FastCheck.Support.ExternalCreateOperation)
    resource(FastCheck.Support.ConversationClosure)
    resource(FastCheck.Support.SupportCaseEvent)
  end
end
