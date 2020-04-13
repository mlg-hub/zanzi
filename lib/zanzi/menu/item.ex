defmodule Zanzibloc.Menu.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field(:added_on, :utc_datetime)
    field(:name, :string)
    field(:price, :integer)
    belongs_to(:departement, Zanzibloc.Menu.Departement)
    belongs_to(:category, Zanzibloc.Menu.Category)
    has_many(:inventory, Zanzibloc.Inventory.Stock)
    has_many(:commandes, Zanzibloc.Ordering.OrderDetail)
    timestamps()
  end

  def changeset(%__MODULE__{} = item, attrs \\ %{}) do
    item
    |> cast(attrs, [:added_on, :name, :price, :category_id, :departement_id])
    # |> foreign_key_constraint([:departement, :category])
    |> validate_required([:name, :price, :category_id])
  end
end
