defmodule ZanziWeb.DepartementController do
  use ZanziWeb, :controller
  alias Zanzibloc.Ordering.OrderingApi

  def stats_kitchen(conn, _params) do
    kit_stats = OrderingApi.get_department_stats(2)
    render(conn, "kitchen.html", stats: kit_stats)
  end

  def stats_bar(conn, _params) do
    bar_stats = OrderingApi.get_department_stats(1)
    render(conn, "bar.html", stats: bar_stats)
  end

  def stats_coffee(conn, _params) do
    cof_stats = OrderingApi.get_department_stats(3)
    render(conn, "coffee.html", stats: cof_stats)
  end

  def stats_restaurant(conn, _params) do
    cof_stats = OrderingApi.get_department_stats(4)
    render(conn, "restaurant.html", stats: cof_stats)
  end

  def stats_mini_bar(conn, _params) do
    cof_stats = OrderingApi.get_department_stats(5)
    render(conn, "mini_bar.html", stats: cof_stats)
  end

  def filter_date(conn, %{"date" => %{"selected_date" => date, "dpt_id" => dpt_id, "dpt" => dpt}}) do
    filtered_result = OrderingApi.filter_by_date(date, dpt_id)
    render(conn, "#{dpt}.html", stats: filtered_result)
  end
end
