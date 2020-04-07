defmodule ZanziWeb.Context do
  @behaviour Plug
  import Plug.Conn

  @spec init(any) :: any
  def init(opts), do: opts

  def call(conn, _) do
    context = build_context(conn)
    IO.inspect(context: context)
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp build_context(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, data} <- ZanziWeb.Auth.TokenAuthentication.verify(token) do
      %{current_user: get_user(data)}
    else
      _ -> %{}
    end
  end

  defp get_user(%{user_id: user_id}) do
    Zanzibloc.Account.AccountApi.lookup(user_id)
  end
end
