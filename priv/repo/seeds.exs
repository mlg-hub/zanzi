alias NimbleCSV.RFC4180, as: CSV
alias Zanzi.Repo
alias Zanzibloc.Account.{AccountApi, Position, User, Role}
NimbleCSV.define(CSV, separator: "\;")

"priv/repo/seed_data/staff.csv"
|> File.read!()
|> CSV.parse_string()
|> Enum.map(fn [_, full_name, position, role, _] ->
  # nil
  # number = :rand.uniform(10000000)

  # when updating
  # number = :rand.uniform(10000000)
  # user = Repo.get_by(User, %{full_name: full_name})

  # with %User{full_name: full_name} <- user do
  #   case Enum.count(String.split(full_name, " ")) > 1 do
  #     true ->
  #       lastname = Enum.at(String.split(full_name, " "), 1)
  #       created_username = String.downcase(lastname, :default) <> Integer.to_string(number)
  #       changeset = Ecto.Changeset.change(user, username: created_username)
  #       updated = Repo.update!(changeset)
  #       IO.inspect(updated)

  #     _ ->
  #       firstname = Enum.at(String.split(String.trim(full_name), " "), 0)
  #       created_username = String.downcase(firstname, :default) <> Integer.to_string(number)
  #       changeset = Ecto.Changeset.change(user, username: created_username)
  #       updated = Repo.update!(changeset)
  #       IO.inspect(updated)
  #   end
  # end

  # User.upload_users(
  #   %{
  #     full_name: full_name,
  #     position_name: position,
  #     role: role,
  #     username: "test" <> Integer.to_string(number)
  #   },
  #   number
  # )
end)
