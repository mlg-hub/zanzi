defmodule Zanzibloc.Cache.ToprintBar do
  use GenServer
  alias ZanziWeb.Presence

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, []}
  end

  def add_new(items) do
    GenServer.cast(__MODULE__, {:add_new_item, items})
  end

  def fetch_pending_print() do
    GenServer.call(__MODULE__, :fetch_pending)
  end

  def handle_cast({:add_new_item, items}, _from, state) do
    send(self(), :print_to_dpt)
    {:noreply, state ++ items}
  end

  def handle_call(:fetch_pending, _from, state) do
    {toPrint, remain} = Enum.split(state, 10)
    {:reply, toPrint, remain}
  end

  # def handle_info(:item_added, state) do
  #   Pro
  # end

  def handle_info(:print_to_dpt, state) do
    isLive = amLive?("departement:zanzi")

    cond do
      isLive ->
        {toPrint_list, remain_list} = Enum.split(state, 10)
        ZanziWeb.Endpoint.broadcast!("commande:bar", "printpaper", %{commande: toPrint_list})

        {:noreply, remain_list}

      true ->
        {:noreply, state}
    end
  end

  def amLive?(topic) do
    presence_list = Presence.list(topic)

    case presence_list["departement:bar"] do
      nil -> false
      _ -> true
    end
  end
end
