defmodule Zanzibloc.Ordering.OrderPayment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_payments" do
    belongs_to(:order, Zanzibloc.Ordering.Order)
    belongs_to(:cashier, Zanzibloc.Account.User, type: :string, foreign_key: :user_id)
    field(:order_total, :integer, null: false)
    field(:order_paid, :integer, null: false)
    timestamps()
  end

  def changeset(%__MODULE__{} = payments, attrs \\ %{}) do
    payments
    |> cast(attrs, [:order_id, :order_total, :order_paid, :user_id])
    |> validate_required([:order_id, :order_total, :order_paid])
  end
end
