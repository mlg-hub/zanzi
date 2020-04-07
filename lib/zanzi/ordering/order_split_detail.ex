defmodule Zanzibloc.Ordering.OrderSplitDetail do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_splits_details" do
    belongs_to(:order_split, Zanzibloc.Ordering.OrderSplit)
    belongs_to(:item, Zanzibloc.Menu.Item)
    belongs_to(:departement, Zanzibloc.Menu.Departement)
    field(:sold_price, :decimal, read_after_writes: true)
    field(:sold_quantity, :integer, read_after_writes: true)
  end

  def changeset(%__MODULE__{} = order_split_details, attrs) do
    order_split_details
    |> cast(attrs, [:order_split_id, :item_id, :departement_id, :sold_price, :sold_quantity])
    |> validate_required([:order_split_id, :item_id, :departement_id, :sold_price, :sold_quantity])
  end
end
