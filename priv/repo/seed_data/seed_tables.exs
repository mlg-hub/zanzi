alias Zanzi.Repo
alias Zanzibloc.Ordering.Table

Enum.each(1..55, fn x ->
  table =
    %Table{}
    |> Table.changeset(%{number: x})
    |> Repo.insert!()

  IO.inspect(table)
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
