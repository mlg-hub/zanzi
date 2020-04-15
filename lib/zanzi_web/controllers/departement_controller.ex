defmodule ZanziWeb.DepartementController do
  use ZanziWeb, :controller

  def stats_kitchen(conn, _params) do
    render(conn, "kitchen.html")
  end

  def stats_bar(conn, _params) do
    render(conn, "bar.html")
  end

  def stats_coffee(conn, _params) do
    render(conn, "coffee.html")
  end
end
