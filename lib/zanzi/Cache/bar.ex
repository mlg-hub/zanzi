defmodule Zanzibloc.Cache.BarCache do
  use GenServer
  alias Zanzibloc.Ordering.OrderingApi

  def start_link do
    IO.puts("#bar is starting")
    GenServer.start_link(__MODULE__, [])
  end

  def init(items) do
    Process.send_after(self(), :load_items, 5000)
    {:ok, items}
  end

  def handle_info(:load_items, bar_items) do
    GenServer.cast(self(), :load_bar_items)
    {:noreply, bar_items}
  end

  def handle_cast(:load_bar_items, state) do
    IO.puts("fecting data from Repo...")
    bar_items = OrderingApi.get_items(:bar)
    {:noreply, [bar_items | state]}
  end
end
