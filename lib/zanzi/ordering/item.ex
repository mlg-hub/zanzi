defmodule Zanzibloc.Ordering.Item do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:name)
    field(:quantity)
    field(:price)
  end

  def changeset(%__MODULE__{} = item, attrs \\ %{}) do
    item
    |> cast(attrs, [:name, :price, :quantity])
    |> validate_required([:price, :quantity, :name])
  end
end
