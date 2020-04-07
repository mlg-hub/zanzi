defmodule Zanzibloc.Account.Position do
  use Ecto.Schema
  import Ecto.Changeset

  schema "positions" do
    field(:position_name, :string)
    many_to_many(:role, Zanzibloc.Account.Role, join_through: "positions_roles")
    many_to_many(:user, Zanzibloc.Account.User, join_through: "users_positions")
  end

  def changeset(%__MODULE__{} = position, attrs) do
    position
    |> cast(attrs, [:position_name])
    |> unique_constraint(:position_name)
    |> validate_required([:position_name])
  end
end
