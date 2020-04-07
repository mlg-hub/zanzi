defmodule ZanziWeb.Schema.Middleware.Authorize do
  @behaviour Absinthe.Middleware
  alias Zanzibloc.Account.User
  require Logger

  def call(resolution, _) do
    #  can accept a second parameter
    with %{current_user: current_user} <- resolution.context do
      Logger.warn("inside the resolution")
      IO.inspect(resolution.context)
      resolution
    else
      _ ->
        resolution
        |> Absinthe.Resolution.put_result({:error, "unauthorized"})
    end
  end
end
