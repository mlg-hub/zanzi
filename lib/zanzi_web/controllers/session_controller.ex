defmodule ZanziWeb.SessionController do
  use ZanziWeb, :controller

  def new(conn, _params) do
    render(conn, "login.html")
  end
end
