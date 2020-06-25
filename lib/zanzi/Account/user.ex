defmodule Zanzibloc.Account.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Zanzibloc.Account.{Position, AccountApi, Role, UsersPositions, PositionRole}
  alias Zanzibloc.Ordering.{OrderOwner}
  alias Zanzi.Repo
  @derive {Jason.Encoder, only: [:full_name]}
  @primary_key {:id, Zanzibloc.Ecto.Ksuid, autogenerate: true}
  schema "users" do
    field(:full_name, :string)
    field(:username, :string)
    field(:password, Comeonin.Ecto.Password)
    field(:plain_pwd, :string)
    has_many(:payments, Zanzibloc.Ordering.OrderPayment)

    many_to_many(:position, Zanzibloc.Account.Position,
      join_through: UsersPositions,
      join_keys: [user_id: :id, position_id: :id]
    )

    has_many(:shift, Zanzibloc.Ordering.CashierShift)

    many_to_many(:orders, Zanzibloc.Ordering.Order,
      join_through: OrderOwner,
      # foreign_key: :current_owner,
      join_keys: [current_owner: :id, order_id: :id]
    )
  end

  def changeset(%__MODULE__{} = user, attrs \\ %{}) do
    user
    |> cast(attrs, [:full_name, :password, :plain_pwd, :username])
    |> validate_required([:full_name, :password, :plain_pwd, :username])
  end

  def upload_users(user, number) do
    system_user = %{
      full_name: user.full_name,
      password: Integer.to_string(number),
      plain_pwd: Integer.to_string(number),
      username: user.username
    }

    # TODO: see how to do it with transaction
    case AccountApi.create_user(system_user) do
      %__MODULE__{} = inserted_user ->
        case create_user_position(%{user: inserted_user, position_name: user.position_name}) do
          %UsersPositions{position_id: position_id} ->
            create_position_role(%{position: position_id, role: user.role})
        end

      _ ->
        :error
    end
  end

  def create_position_role(%{} = data) do
    role = %{name: String.trim(data.role)}

    case(Repo.get_by(Role, role)) do
      %Role{} = myrole ->
        create_role_relation(myrole, data.position)

      _ ->
        inserted_role =
          %Role{}
          |> Role.changeset(role)
          |> Repo.insert!()

        case inserted_role do
          %Role{} = myrole -> create_role_relation(myrole, data.position)
          _ -> :error
        end
    end
  end

  def create_role_relation(role, position_id) do
    %PositionRole{}
    |> PositionRole.changeset(%{role_id: role.id, position_id: position_id})
    |> Repo.insert!(on_conflict: :nothing)
  end

  def create_user_position(%{user: inserted_user, position_name: position}) do
    position_info = %{
      position_name: String.trim(position) |> String.downcase(:default)
    }

    case Repo.get_by(Position, position_info) do
      %Position{} = position ->
        create_relation(position, inserted_user)

      _ ->
        inserted_position =
          %Position{}
          |> Position.changeset(position_info)
          |> Repo.insert!()

        case inserted_position do
          %Position{} = position -> create_relation(position, inserted_user)
          _ -> {:error}
        end
    end
  end

  defp create_relation(position, user) do
    %UsersPositions{}
    |> UsersPositions.changeset(%{user_id: user.id, position_id: position.id})
    |> Repo.insert!()
  end
end
