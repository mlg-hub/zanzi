defmodule Zanzibloc.Account.Role do
  use Ecto.Schema
  import Ecto.Changeset
  alias Zanzibloc.Account.Position

  schema "roles" do
    field(:name, :string)
    many_to_many(:position, Position, join_through: "positions_roles")
    timestamps()
  end

  def changeset(%__MODULE__{} = role, attrs) do
    role
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
