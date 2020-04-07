defmodule Zanzibloc.Ordering.OrderSplit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orders" do
    field(:split_code, :string)
    field(:split_total, :integer)
  end

  def changeset(%__MODULE__{} = split, attrs \\ %{}) do
    split
    |> cast(attrs, [:order_id, :spliter_id, :split_code, :split_total])
    |> validate_required([:order_id, :spliter_id, :split_code])
  end
end
