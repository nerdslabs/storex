defmodule Storex.Message do
  @derive {Jason.Encoder, only: [:type, :store, :data, :request, :session]}
  defstruct [:type, :store, :data, :request, :session]

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

  def cast(%{
        "type" => "error",
        "store" => store,
        "data" => data,
        "request" => request,
        "session" => session
      }) do
    {:ok,
     %__MODULE__{type: "error", store: store, data: data, request: request, session: session}}
  end

  def cast(_) do
    {:error, "Unknown message type"}
  end
end
