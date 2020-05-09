defmodule Zanzibloc.Ordering.VoidReason do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_void_reasons" do
    field(:void_reason, :string, null: false)
    belongs_to(:order, Zanzibloc.Ordering.Order)
    timestamps()
  end

  def changeset(%__MODULE__{} = ovr, attrs) do
    ovr
    |> cast(attrs, [:order_id, :void_reason])
    |> validate_required([:order_id, :void_reason])
  end
end
