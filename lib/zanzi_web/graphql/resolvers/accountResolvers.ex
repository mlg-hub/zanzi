defmodule ZanziWeb.Resolvers.AccountsResolvers do
  alias Zanzibloc.Account.{AccountApi}

  def login(_, %{username: username, password: password}, _) do
    case AccountApi.authenticate(username, password) do
      {:ok, user} ->
        token = ZanziWeb.Auth.TokenAuthentication.sign(user)

        {:ok, %{token: token, user: user}}

      _ ->
        {:error, "incorrect email or password"}
    end
  end

  def list_users(_, args, _) do
    {:ok, AccountApi.list_users(args)}
  end

  def load_user_position(parent, _, _) do
    AccountApi.load_user_position(parent)
  end

  def load_position_role(parent, _, _) do
    AccountApi.load_position_role(parent)
  end

  def me(_, _, %{context: %{current_user: current_user}}) do
    {:ok, current_user}
  end

  def me(_, _, _) do
    {:ok, nil}
  end
end
