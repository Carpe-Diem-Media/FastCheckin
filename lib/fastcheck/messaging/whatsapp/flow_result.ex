defmodule FastCheck.Messaging.WhatsApp.FlowResult do
  @moduledoc """
  Result returned by the WhatsApp conversation state machine.
  """

  @enforce_keys [:conversation, :response_body]
  defstruct [
    :conversation,
    :response_body,
    :session_fields,
    send_reply?: true
  ]

  @type t :: %__MODULE__{
          conversation: struct(),
          response_body: String.t(),
          session_fields: map() | nil,
          send_reply?: boolean()
        }
end

defimpl Inspect, for: FastCheck.Messaging.WhatsApp.FlowResult do
  import Inspect.Algebra

  def inspect(result, _opts) do
    concat([
      "#FlowResult<send_reply?: ",
      to_string(result.send_reply?),
      ", response_body: [FILTERED]>"
    ])
  end
end
