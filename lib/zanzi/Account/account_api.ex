defmodule Zanzibloc.Account.AccountApi do
  alias Zanzi.Repo
  alias Zanzibloc.Account.{Position, User, Role}
  alias Comeonin.Ecto.Password
  import Ecto.Query

  def create_user(%{} = attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert!()
  end

  def create_position(%{position: attrs, user: user}) do
    %Position{}
    |> Position.changeset(attrs)
    |> Repo.insert!()
  end

  def create_role(%{} = attrs) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert!()
  end

  def list_users(args) do
    {:ok, users} = Zanzibloc.Cache.UserCache.get_all_users(args)
    users
  end

  def get_all_users() do
    Repo.all(from(u in User, where: u.status == 0, preload: [position: :role]))
  end

  def get_user(id) do
    Repo.get(User, id)
  end

  def authenticate(uname, pwd) do
    user = Repo.get_by(User, %{username: uname})

    with %User{password: digest} <- user,
         true <- Password.valid?(pwd, digest) do
      # user = Repo.preload(user, position: [:role])
      # user = Repo.all(Ecto.assoc(user, :position)) # here only the %Position{} is returned

      user = Repo.one(from(u in User, where: u.id == ^user.id, preload: [position: :role]))

      {:ok, user}
      # with %User{position: pos} <- user do
      #   myrole =
      #     pos
      #     |> Enum.at(0)

      #   myrole = myrole.role |> Enum.at(0)
      #   {:role, myrole}
      # end
    else
      _ -> {:error, "error occured"}
    end
  end

  def lookup(user_id) do
    case Repo.one(from(u in User, where: u.id == ^user_id, preload: [position: :role])) do
      %User{} = user -> user
      _ -> nil
    end
  end

  def load_user_position(user) do
    %Position{}
    |> Repo.get(user.position.id)
  end

  def load_position_role(position) do
    role =
      %Role{}
      |> Repo.get(position.role)
  end
end
