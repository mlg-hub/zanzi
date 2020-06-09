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

  def handle_info(
        {:success_update, item},
        socket
      ) do
    ZanziWeb.Endpoint.broadcast!("admin:zanzi", "updated_item", %{
      updated_item: item
    })

    {:noreply, socket}
  end

  def handle_info(:fail_update, socket) do
    IO.puts("in fail handle")
    {:noreply, socket}
  end
end
