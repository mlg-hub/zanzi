defmodule ZanziWeb.OrderView do
  use ZanziWeb, :view

  def get_total(orders) do
    Enum.reduce(orders, 0, fn %{total: tot}, acc -> acc + tot end)
  end

  def get_total_payments(orders) do
    Enum.reduce(orders, 0, fn %{payments: pay_array}, acc ->
      acc + Enum.at(pay_array, 0).order_paid
    end)
  end
end
