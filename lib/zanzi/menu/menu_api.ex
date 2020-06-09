defmodule Zanzibloc.Menu.MenuApi do
  alias Zanzibloc.Menu.{Item, Departement, Category}
  alias Zanzi.Repo
  import Ecto.Query, warn: false
  alias Zanzibloc.Cache.{BarCache, KitchenCache, MiniBar, Restaurant}

  def list_categories do
    Repo.all(Category)
  end

  def list_categories_html do
    query = Category |> select([c], {c.name, c.id})
    Repo.all(query)
  end

  def list_all_items() do
    query =
      Item
      |> join(:inner, [i], dpt in assoc(i, :departement))
      |> order_by([i, dpt], asc: i.name)
      |> preload([i, dpt], departement: dpt)

    Repo.all(query)
  end

  def create_item_html(changeset) do
    Repo.insert(changeset)
  end

  def get_bar_items do
    BarCache.get_all_item()
  end

  def get_pid do
  end

  def get_category!(id), do: Repo.get!(Category, id)

  def get_all_departement do
    query = from(d in Departement, where: d.active_status == 0)
    Repo.all(query)
  end

  def get_all_departement_html do
    query = from(d in Departement, where: d.active_status == 0, select: {d.name, d.id})
    Repo.all(query)
  end

  def get_all_departement_admin do
    query = from(d in Departement, where: d.active_status == 0)
    Repo.all(query)
  end

  def create_category(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  def delete_category(%Category{} = category) do
    Repo.delete(category)
  end

  def change_category(%Category{} = category) do
    Category.changeset(category, %{})
  end

  @search [Item, Category]
  def search(term) do
    pattern = "%#{term}%"
    Enum.flat_map(@search, &search_ecto(&1, pattern))
  end

  def menu_items(id) do
    IO.puts("menu items was calleda")
    IO.inspect(id)

    cond do
      id == "1" or id == 1 ->
        {:ok, items} = BarCache.get_all_item()
        items

      id == "2" or id == 2 ->
        {:ok, items} = KitchenCache.get_all_item()
        items

      id == "4" or id == 4 ->
        {:ok, items} = Restaurant.get_all_item()
        items

      id == "5" or id == 5 ->
        {:ok, items} = MiniBar.get_all_item()
        items

      true ->
        IO.puts("i was called with id #{id}")
        []
    end
  end

  def get_all_from_department(id) do
    Enum.flat_map(@search, &search_ecto(&1, id))
  end

  defp search_ecto(ecto_schema, id) do
    IO.inspect("patrick")
    # id = Integer.to_string(id)
    Repo.all(from(q in ecto_schema, where: q.departement_id == ^id, order_by: [asc: :name]))
  end

  # defp search_ecto(ecto_schema, pattern) when is_bitstring(pattern) do
  #   IO.inspect("run here in pattern")

  #   Repo.all(
  #     from(q in ecto_schema,
  #       where: ilike(q.name, ^pattern)
  #       # or ilike(q.description, ^pattern)
  #     )
  #   )
  # end

  def list_items(args) do
    IO.inspect(args)

    args
    |> items_query
    |> Repo.all()
  end

  defp items_query(args) do
    # query is the Item
    Enum.reduce(args, Item, fn
      {:order, order}, query ->
        query |> order_by({^order, :name})

      {:filter, filter}, query ->
        query |> filter_with(filter)
    end)
  end

  defp filter_with(query, filter) do
    Enum.reduce(filter, query, fn
      {:name, name}, query ->
        from(q in query, where: ilike(q.name, ^"%#{name}%"))

      {:priced_above, price}, query ->
        from(q in query, where: q.price >= ^price)

      {:priced_below, price}, query ->
        from(q in query, where: q.price <= ^price)

      {:added_after, date}, query ->
        from(q in query, where: q.added_on >= ^date)

      {:added_before, date}, query ->
        from(q in query, where: q.added_on <= ^date)

      {:category, category_name}, query ->
        from(q in query,
          join: c in assoc(q, :category),
          where: ilike(c.name, ^"%#{category_name}%")
        )

      {:tag, tag_name}, query ->
        from(q in query,
          join: t in assoc(q, :tags),
          where: ilike(t.name, ^"%#{tag_name}%")
        )
    end)
  end

  def get_item!(id), do: Repo.get!(Item, id)

  def create_item(attrs \\ %{}) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  def update_item(%Item{} = item, attrs) do
    require Integer
    query = Repo.get(Item, attrs.id)

    {:ok, item_changeset} =
      query
      |> Item.update_changeset(attrs)
      |> Repo.update()

    item = Repo.preload(item_changeset, :departement)
    item
  end

  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end

  def change_item(%Item{} = item) do
    Item.changeset(item, %{})
  end

  def data() do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  def query(Item, args) do
    items_query(args)
  end

  def query(queryable, _) do
    queryable
  end
end
