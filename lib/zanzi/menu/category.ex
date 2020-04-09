defmodule Zanzibloc.Menu.Category do
  use Ecto.Schema
  import Ecto.Changeset
  alias Zanzi.Repo

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

  def check_cat_exitstance_or_insert(category, dept_id) do
    clean_cat = String.downcase(String.trim(category))

    case Repo.get_by(__MODULE__, %{name: clean_cat}) do
      %__MODULE__{} = cat ->
        cat.id

      _ ->
        c =
          %__MODULE__{}
          |> changeset(%{name: clean_cat, departement_id: dept_id})

        case Repo.insert!(c) do
          %__MODULE__{} = cat ->
            cat.id

          _ ->
            nil
        end
    end
  end
end
