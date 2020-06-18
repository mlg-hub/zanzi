defmodule ZanziWeb.MenuItemsController do
  use ZanziWeb, :controller
  alias Zanzibloc.Menu.{MenuApi, Item}
  plug(:load_categories when action in [:all, :edit, :create, :delete])

  # # page 103
  # def action(conn, _) do
  #   apply(__MODULE__, action_name(conn), [conn, conn.params, conn.assigns.current_user])
  # end

  def all(conn, _params) do
    menu_items = MenuApi.list_all_items()
    items = Enum.take(menu_items, 100)
    depts = MenuApi.get_all_departement_admin()
    cats = MenuApi.list_categories()
    render(conn, "all.html", list: items, depts: depts, cats: cats)
  end

  def cats_all(conn, _params) do
    cats = MenuApi.list_categories()
    IO.inspect(cats)
    render(conn, "cats.html", cats: cats)
  end

  def new_item(conn, %{"item" => item_info}) do
    %{"category_id" => cat_id, "dpt_id" => dpt_id, "name" => name, "price" => price} = item_info

    item_changeset =
      %Item{}
      |> Item.changeset(%{
        name: name,
        price: price,
        category_id: cat_id,
        departement_id: dpt_id
      })

    case MenuApi.create_item_html(item_changeset) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Item created successfully.")
        |> redirect(to: Routes.menu_items_path(conn, :all))

      {:error, changeset} ->
        render(conn, "all.html", changeset: changeset)
    end
  end

  defp load_categories(conn, _) do
    dpt = MenuApi.get_all_departement_html()
    cats = MenuApi.list_categories_html()

    conn
    |> assign(:categories, cats)
    |> assign(:depts, dpt)
  end
end
