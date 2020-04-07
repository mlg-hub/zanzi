defmodule Zanzibloc.Account.PositionRole do
  use Ecto.Schema
  alias Zanzibloc.Account.{Role, Position}
  import Ecto.Changeset

  schema "positions_roles" do
    belongs_to(:role, Role, foreign_key: :role_id)
    belongs_to(:position, Position, foreign_key: :position_id)
  end

  def changeset(%__MODULE__{} = position_role, attrs) do
    position_role
    |> cast(attrs, [:role_id, :position_id])

    # |> unique_constraint(:position_id, :role_id)
  end
end
