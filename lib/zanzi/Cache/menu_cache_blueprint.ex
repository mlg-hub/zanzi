defmodule Zanzibloc.Cache.BluePrint do
  defmacro __using__(opts) do
    {:ok, departement_id} = Keyword.fetch(opts, :id)
    {:ok, module} = Keyword.fetch(opts, :module)
    IO.inspect(opts)

    quote do
      use GenServer
      alias Zanzibloc.Menu.MenuApi

      def start_link(_) do
        IO.puts("#{unquote(departement_id)} is starting")
        GenServer.start_link(unquote(module), [], name: unquote(module))
      end

      def init(items) do
        Process.send_after(self(), :load_items, 5000)
        {:ok, items}
      end

      def get_all_item() do
        GenServer.call(unquote(module), :get_items)
      end

      def handle_info(:load_items, bar_items) do
        GenServer.cast(self(), :load_bar_items)
        {:noreply, bar_items}
      end

      def handle_cast(:load_bar_items, state) do
        IO.puts("fecting data from Repo...")
        bar_items = MenuApi.get_all_from_department(1)
        {:noreply, [bar_items | state]}
      end

      def handle_call(:get_items, _from, state) do
        {:reply, {:ok, List.flatten(state)}, state}
      end
    end
  end
end
