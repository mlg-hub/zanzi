defmodule Zanzibloc.Ordering.TableOrders do
  use Ecto.Schema
  import Ecto.Changeset

  schema("tables_orders") do
    belongs_to(:table, Zanzibloc.Ordering.Table)
    belongs_to(:order, Zanzibloc.Ordering.Order)
  end

  def changeset(%__MODULE__{} = table_order, attrs \\ %{}) do
    table_order
    |> cast(attrs, [:table_id, :order_id])
    |> validate_required([:table_id, :order_id])
  end
end
