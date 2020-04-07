defmodule Zanzibloc.Menu.Departement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "departements" do
    field(:name, :string, null: false)
    has_many(:categories, Zanzibloc.Menu.Category)
    has_many(:items, Zanzibloc.Menu.Item)
    timestamps()
  end

  def changeset(%__MODULE__{} = departement, attrs \\ %{}) do
    departement
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
