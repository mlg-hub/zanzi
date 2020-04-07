defmodule Zanzibloc.Ordering.OrderMerged do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_merges" do
    belongs_to(:main_order, Zanzibloc.Ordering.Order)
    belongs_to(:sub_order, Zanzibloc.Ordering.Order)
    has_many(:order_merged_detail, Zanzibloc.Ordering.OrderDetail)
    belongs_to(:user, Zanzibloc.Account.User, type: :string)
    timestamps()
  end

  def changeset(%__MODULE__{} = merged, attrs \\ %{}) do
    merged
    |> cast(attrs, [:main_order_id, :user_id, :sub_order_id])
    |> validate_required([:main_order_id, :user_id, :sub_order_id])
  end
end
