alias Zanzibloc.Menu.Departement
alias Zanzibloc.Menu.Category
alias Zanzi.Repo
alias Zanzibloc.Menu.Item

Enum.each(["Kitchen", "Bar", "Coffee"], fn x ->
  departement =
    %Departement{}
    |> Departement.changeset(%{name: x})
    |> Repo.insert!()

  # IO.inspect(departement)
end)





# |> Enum.map(fn departement ->
#   categories =
#     Enum.map(1..5, fn x ->
#       category =
#         %Category{}
#         |> Category.changeset(%{name: Name.title(), departement_id: departement.id})
#         |> Repo.insert!()
#     end)

#   # IO.inspect(categories)
# end)
# |> Enum.each(fn category ->
#   Enum.each(category, fn c ->
#     Enum.map(1..20, fn x ->
#       myitem =
#         %Item{}
#         |> Item.changeset(%{
#           added_on: Date.utc_today(),
#           name: Food.dish(),
#           price: Decimal.new(:rand.uniform(100_000)),
#           category_id: c.id,
#           departement_id: c.departement_id
#         })
#         |> Repo.insert!()

#       IO.inspect(myitem)
#     end)
#   end)
# end)
