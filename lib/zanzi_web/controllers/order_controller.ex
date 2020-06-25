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

  def voided(conn, _params) do
    orders = OrderingApi.get_bill(:voided)
    render(conn, "voided.html", orders: orders)
  end

  def unpaid(conn, _params) do
    #  first get the real total then find the order payment amount
    # in payment table
    orders = OrderingApi.get_bill(:unpaid)
    render(conn, "unpaid.html", orders: orders)
  end

  def complementary(conn, _params) do
    #  first get the real total then find the order payment amount
    # in payment table
    orders = OrderingApi.get_bill(:complementary)
    render(conn, "complementary.html", orders: orders)
  end

  def remain(conn, _params) do
    #  first get the real total then find the order payment amount
    # in payment table
    orders = OrderingApi.get_bill(:remain)
    orders = Enum.reject(orders, fn o -> Enum.at(o.payments, 0).order_paid == 0 end)
    render(conn, "remain.html", orders: orders)
  end

  def pending(conn, _params) do
    orders = OrderingApi.get_bill(:pending)
    render(conn, "pending.html", orders: orders)
  end

  def detail(conn, %{"id" => id}) do
    detailed_order = OrderingApi.get_order_details_html(id)
    render(conn, "detail.html", order: detailed_order)
  end

  def filter_date(conn, %{
        "date" => %{
          "selected_date" => date,
          "order_type" => order_type,
          "order_route" => order_route
        }
      }) do
    filtered_result = OrderingApi.filter_by_date(:order, date, order_type)
    render(conn, "#{order_route}.html", orders: filtered_result)
  end

  def filter_shift(conn, %{
        "date" => %{
          "selected_shift" => shift,
          "order_type" => order_type,
          "order_route" => order_route
        }
      }) do
    filtered_result = OrderingApi.filter_by_shift(:order_shift, shift, order_type)
    render(conn, "#{order_route}.html", orders: filtered_result)
  end
end
