alias NimbleCSV.RFC4180, as: CSV
alias Zanzi.Repo
alias Zanzibloc.Menu.{Category, Departement, Item}
NimbleCSV.define(CSV, separator: "\,")

"priv/repo/seed_data/zanzi_safe.csv"
|> File.read!()
|> CSV.parse_string()
|> Enum.each(fn [item, category, price, departement] ->
  # check for dpt existance
  resp_dept = Departement.check_dpt_existance_or_insert(departement)
  resp_category = Category.check_cat_exitstance_or_insert(category, resp_dept)

  cond do
    resp_dept != nil && resp_category != nil ->
      %Item{}
      |> Item.changeset(%{
        name: item,
        price: price,
        category_id: resp_category,
        departement_id: resp_dept
      })
      |> Repo.insert!()

    true ->
      {:error, "nop!"}
  end

  IO.inspect(resp_dept)

  dpt =
    %Departement{}
    |> Departement.changeset(%{name: departement})
end)
