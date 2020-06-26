defmodule Zanzibloc.Ordering.CashierShift do
  use Ecto.Schema
  # import Ecto.Query
  import Ecto.Changeset
  # @derive {Jason.Encoder, only: [:id, :shift_end, :shift_start]}
  schema "cashier_shifts" do
    field(:shift_start, :utc_datetime)
    field(:shift_end, :utc_datetime)
    field :shift_status, :integer
    has_many(:orders, Zanzibloc.Ordering.CashierShift, on_delete: :nothing)
    belongs_to(:user, Zanzibloc.Account.User, type: :string)
    timestamps(type: :utc_datetime)
  end

  def create_new_shift(%__MODULE__{} = shift, attrs \\ %{}) do
    shift
    |> cast(attrs, [:user_id, :shift_start])
    |> validate_required([:user_id])
  end

  def create_closing_chgset(%__MODULE__{} = shift, attrs) do
    shift
    |> cast(attrs, [:shift_status, :shift_end])
  end

  def close_shift(%__MODULE__{} = shift_changeset) do
    shift_changeset
    |> change()
    |> put_change(:shift_status, 0)
  end
end
