defmodule ZanziWeb.OrderView do
  use ZanziWeb, :view

  def get_total(orders) do
    Enum.reduce(orders, 0, fn %{total: tot}, acc -> acc + tot end)
  end
end
