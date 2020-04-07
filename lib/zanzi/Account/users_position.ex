defmodule Zanzibloc.Account.UsersPositions do
  use Ecto.Schema
  alias Zanzibloc.Account.{User, Position}
  import Ecto.Changeset

  schema "users_positions" do
    belongs_to(:user, User, foreign_key: :user_id, type: :string)
    belongs_to(:position, Position, foreign_key: :position_id)
  end

  def changeset(%__MODULE__{} = users_postions, attrs) do
    users_postions
    |> cast(attrs, [:user_id, :position_id])
    |> unique_constraint(:user_id)
  end
end
