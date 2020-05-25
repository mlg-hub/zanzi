defmodule ZanziWeb.SessionController do
  use ZanziWeb, :controller

  def login(conn, _params) do
    render(conn, "login.html")
  end
end
