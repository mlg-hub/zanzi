defmodule Zanzibloc.Inventory.Stock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "iteminventories" do
    belongs_to(:item, Zanzibloc.Menu.Item)
    field(:added_on, :date)
    field(:qty_remain, :integer)
    field(:qty_sold, :integer)
    timestamps()
  end

  def changeset(%__MODULE__{} = stock, attrs) do
    stock
    |> cast(attrs, [:added_on, :qty_remain, :qty_sold])
    |> foreign_key_constraint(:item)
    |> validate_required([:added_on, :qty_remain, :qty_sold])
  end
end
