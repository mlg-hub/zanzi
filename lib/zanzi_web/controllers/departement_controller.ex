defmodule ZanziWeb.DepartementController do
  use ZanziWeb, :controller
  alias Zanzibloc.Ordering.OrderingApi
  plug :load_shits

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
    cof_stats = OrderingApi.get_department_stats(5)
    render(conn, "restaurant.html", stats: cof_stats)
  end

  def stats_mini_bar(conn, _params) do
    cof_stats = OrderingApi.get_department_stats(6)
    render(conn, "mini_bar.html", stats: cof_stats)
  end

  def filter_date(conn, %{"date" => %{"selected_date" => date, "dpt_id" => dpt_id, "dpt" => dpt}}) do
    filtered_result = OrderingApi.filter_by_date(date, dpt_id)
    render(conn, "#{dpt}.html", stats: filtered_result)
  end

  def filter_shift(conn, %{
        "shift" => %{"selected_shift" => shift_id, "dpt_id" => dpt_id, "dpt" => dpt}
      }) do
    filtered_result = OrderingApi.filter_by_shift(shift_id, dpt_id)

    shift =
      OrderingApi.get_one_shift(shift_id)
      |> format_shift()

    render(conn, "#{dpt}.html", stats: filtered_result, shift: shift)
  end

  defp load_shits(conn, _params) do
    shifts = OrderingApi.get_all_cashier_shifts()

    shifts = format_shift(shifts)

    conn
    |> assign(:shifts, shifts)
    |> assign(:shift, nil)
  end

  defp format_shift(shifts) when is_list(shifts) do
    Enum.map(shifts, fn s ->
      stringing_from = Enum.at(String.split(DateTime.to_string(s.shift_start), "Z"), 0)
      stringing_end = Enum.at(String.split(DateTime.to_string(s.shift_end), "Z"), 0)
      IO.inspect(stringing_from)
      stringing = "From: #{stringing_from},to: #{stringing_end}"

      {stringing, s.id}
    end)
  end

  defp format_shift(s) when is_map(s) do
    stringing_from = Enum.at(String.split(DateTime.to_string(s.shift_start), "Z"), 0)
    stringing_end = Enum.at(String.split(DateTime.to_string(s.shift_end), "Z"), 0)
    "From: #{stringing_from},to: #{stringing_end}"
  end
end
