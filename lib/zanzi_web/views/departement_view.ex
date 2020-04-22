defmodule ZanziWeb.DepartementView do
  use ZanziWeb, :view

  def get_total(stats) do
    Enum.reduce(stats, 0, fn %{"sold_quantity" => qty, "sold_price" => price}, acc ->
      acc + qty * price
    end)
  end

  # def get_total_payments(orders) do
  #   Enum.reduce(orders, 0, fn %{payments: pay_array}, acc ->
  #     acc + Enum.at(pay_array, 0).order_paid
  #   end)
  # end
end
