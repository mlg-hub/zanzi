defmodule Zanzibloc.Ordering.Table do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tables" do
    field(:number, :integer, null: false)
    has_many(:orders, Zanzibloc.Ordering.Order)
    timestamps()
  end

  def changeset(%__MODULE__{} = table, attrs) do
    table
    |> cast(attrs, [:number])
    |> validate_required([:number])
  end
end
