defmodule Zanzibloc.Menu.Departement do
  use Ecto.Schema
  import Ecto.Changeset
  alias Zanzi.Repo
  @derive {Jason.Encoder, only: [:name, :id]}
  schema "departements" do
    field(:name, :string, null: false)
    field(:active_status, :integer)
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

  def check_dpt_existance_or_insert(department) do
    clean_dpt = String.downcase(String.trim(department))

    IO.inspect(clean_dpt)

    case Repo.get_by(__MODULE__, %{name: clean_dpt}) do
      %__MODULE__{} = dpt ->
        dpt.id

      _ ->
        d =
          %__MODULE__{}
          |> changeset(%{name: clean_dpt})

        case Repo.insert!(d) do
          %__MODULE__{} = dpt ->
            dpt.id

          _ ->
            nil
        end
    end
  end
end
