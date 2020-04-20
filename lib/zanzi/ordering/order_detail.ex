defmodule Zanzibloc.Ordering.OrderDetail do
  use Ecto.Schema
  import Ecto.Changeset

  schema("order_details") do
    belongs_to(:order, Zanzibloc.Ordering.Order)
    belongs_to(:item, Zanzibloc.Menu.Item)
    belongs_to(:departement, Zanzibloc.Menu.Departement)
    field(:sold_price, :integer, read_after_writes: true)
    field(:sold_quantity, :integer, read_after_writes: true)
    field(:split_status, :integer, default: 0, read_after_writes: true)
    # split_status to tell that this item should no longer be calculate/considered
    # as belonging to this order
    timestamps()
  end

  def changeset(%__MODULE__{} = order_detail, attrs \\ %{}) do
    order_detail
    |> cast(attrs, [:sold_price, :sold_quantity, :order_id, :item_id, :departement_id])
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:departement_id)
    |> validate_required([:sold_price, :sold_quantity])
  end

  def split_changeset(%__MODULE__{} = order_detail, attrs \\ %{}) do
    order_detail
    |> cast(attrs, [:split_status])
    |> validate_required([:split_status])
  end
end
