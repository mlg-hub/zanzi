defmodule Zanzibloc.Menu.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field(:name, :string, null: false)
    belongs_to(:departement, Zanzibloc.Menu.Departement)
    has_many(:items, Zanzibloc.Menu.Item)
    timestamps()
  end

  def changeset(%__MODULE__{} = category, attrs \\ %{}) do
    category
    |> cast(attrs, [:name, :departement_id])
    # |> foreign_key_constraint(:departement)
    |> unique_constraint(:name)
  end
end
