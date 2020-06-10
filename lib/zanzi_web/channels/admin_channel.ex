defmodule ZanziWeb.AdminChannel do
  use ZanziWeb, :channel
  alias Zanzibloc.Menu.{MenuApi, Item}

  def join("admin:zanzi", _params, socket) do
    {:ok, %{active: true, message: "join with success"}, socket}
  end

  def handle_in("update_item", %{"body" => new_item}, socket) do
    # IO.inspect(new_item)
    # IO.inspect(new_item['name'])

    new_item = %{
      id: new_item["id"],
      name: new_item["name"],
      price: new_item["price"],
      departement_id: new_item["selectedDept"]
    }

    updated_item = MenuApi.update_item(%Item{}, new_item)

    IO.inspect(updated_item)

    case updated_item do
      %Item{} = item -> send(self(), {:success_update, item})
      _ -> send(self(), :fail_update)
    end

    {:noreply, socket}
  end

  def handle_in("new_item", %{"body" => item_info}, socket) do
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
      %Item{} = item ->
        send(self(), {:success_insert, item})
        {:noreply, socket}

      _ ->
        send(self(), :fail_update)
        {:noreply, socket}
    end
  end

  def handle_info(
        {:success_update, item},
        socket
      ) do
    ZanziWeb.Endpoint.broadcast!("admin:zanzi", "updated_item", %{
      updated_item: item
    })

    {:noreply, socket}
  end

  def handle_info(
        {:success_insert, item},
        socket
      ) do
    ZanziWeb.Endpoint.broadcast!("admin:zanzi", "insert_item", %{
      inserted_item: "success"
    })

    {:noreply, socket}
  end

  def handle_info(:fail_update, socket) do
    IO.puts("in fail handle")
    {:noreply, socket}
  end
end
