defmodule ZanziWeb.OrderController do
  use ZanziWeb, :controller
  alias Zanzibloc.Ordering.OrderingApi

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def cleared(conn, _params) do
    orders = OrderingApi.get_bill(:cleared)
    render(conn, "cleared.html", orders: orders)
  end

  def incomplete(conn, _params) do
    orders = OrderingApi.get_bill(:incomplete)
    render(conn, "incomplete.html", orders: orders)
  end

  def pending(conn, _params) do
    orders = OrderingApi.get_bill(:pending)
    render(conn, "pending.html", orders: orders)
  end
end
