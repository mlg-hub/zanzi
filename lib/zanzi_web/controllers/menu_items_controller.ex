defmodule ZanziWeb.MenuItemsController do
  use ZanziWeb, :controller
  alias Zanzibloc.Menu.MenuApi

  def all(conn, _params) do
    menu_items = MenuApi.list_all_items()
    # IO.inspect(Enum.take(menu_items, 3))
    render(conn, "all.html", items: menu_items)
  end
end
