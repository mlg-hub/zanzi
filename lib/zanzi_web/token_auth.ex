defmodule ZanziWeb.Auth.TokenAuthentication do
  @user_salt "this is my salt to covid192020"

  def sign(data) do
    Phoenix.Token.sign(ZanziWeb.Endpoint, @user_salt, %{user_id: data.id})
  end

  def verify(token) do
    Phoenix.Token.verify(ZanziWeb.Endpoint, @user_salt, token, max_age: 24 * 3600)
  end

  def logout() do
  end
end
