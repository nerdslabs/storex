defmodule Storex.Message do
  @derive {Jason.Encoder, only: [:type, :store, :data, :request, :session]}
  defstruct [:type, :store, :data, :request, :session]

  def cast(%{"type" => "ping", "request" => request}) do
    {:ok, %__MODULE__{type: "ping", request: request}}
  end

  def cast(%{
        "type" => "join",
        "store" => store,
        "data" => data,
        "request" => request,
        "session" => session
      }) do
    {:ok, %__MODULE__{type: "join", store: store, data: data, request: request, session: session}}
  end

  def cast(%{"type" => "join", "store" => store, "data" => data, "request" => request}) do
    {:ok, %__MODULE__{type: "join", store: store, data: data, request: request}}
  end

  def cast(%{
        "type" => "mutation",
        "store" => store,
        "data" => %{"name" => name, "data" => data},
        "request" => request,
        "session" => session
      }) do
    {:ok,
     %__MODULE__{
       type: "mutation",
       store: store,
       data: %{name: name, data: data},
       request: request,
       session: session
     }}
  end

  # `error` frames only ever travel server to client, and are built as plain maps
  # in `Storex.Socket`. Casting one here made it past the allowlist and then hit
  # `Storex.Socket.message_handle/2`, which has no clause for it, so a client
  # could kill its connection process with a well-formed frame.
  def cast(_) do
    {:error, "Unknown message type"}
  end
end
