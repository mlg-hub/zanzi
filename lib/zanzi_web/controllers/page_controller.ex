defmodule ZanziWeb.PageController do
  use ZanziWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
