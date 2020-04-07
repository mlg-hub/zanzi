defmodule Zanzibloc.Ordering.OrderOwner do
  use Ecto.Schema
  import Ecto.Changeset

  schema("orders_owners") do
    belongs_to(:order, Zanzibloc.Ordering.Order)
    belongs_to(:current, Zanzibloc.Account.User, type: :string, foreign_key: :current_owner)
    belongs_to(:from, Zanzibloc.Account.User, type: :string, foreign_key: :from_owner)
    field(:transfer_to, :string)
    field(:status, :string)
    timestamps()
  end

  def changeset(%__MODULE__{} = orderOwner, attrs \\ %{}) do
    orderOwner
    |> cast(attrs, [:order_id, :current_owner])
    |> validate_required([:order_id, :current_owner])
  end

  def transfer_request_changeset(%__MODULE__{} = orderOwner, update_attrs) do
    orderOwner
    |> cast(update_attrs, [:order_id, :transfer_to, :status])
    |> validate_required([:order_id, :transfer_to, :status])
  end

  def reject_request_changeset(%__MODULE__{} = orderOwner, attrs) do
    orderOwner
    |> cast(attrs, [:order_id, :status, :transfer_to])
    |> validate_required([:order_id, :status])
  end

  def accept_request_changeset(%__MODULE__{} = orderOwer, attrs) do
    orderOwer
    |> cast(attrs, [:order_id, :status, :transfer_to, :from_owner, :current_owner])
  end
end
