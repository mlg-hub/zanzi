defmodule Zanzibloc.Cache.PrintBluePrint do
  defmacro __using__(opts) do
    {:ok, departement} = Keyword.fetch(opts, :departement)
    {:ok, module} = Keyword.fetch(opts, :module)

    quote do
      use GenServer
      alias ZanziWeb.Presence

      def start_link(_) do
        GenServer.start_link(unquote(module), [], name: unquote(module))
      end

      def init(_) do
        {:ok, []}
      end

      def add_new(items) do
        GenServer.cast(unquote(module), {:add_new_item, items})
      end

      def fetch_pending_print() do
        GenServer.call(unquote(module), :fetch_pending)
      end

      def handle_cast({:add_new_item, items}, state) do
        send(self(), :print_to_dpt)
        {:noreply, state ++ [items]}
      end

      def handle_call(:fetch_pending, _from, state) do
        {toPrint, remain} = Enum.split(state, 10)
        {:reply, toPrint, remain}
      end

      def handle_info(:print_to_dpt, state) do
        isLive = amLive?("departement:zanzi")

        cond do
          isLive ->
            {toPrint_list, remain_list} = Enum.split(state, 10)

            ZanziWeb.Endpoint.broadcast!("commande:#{unquote(departement)}", "printpaper", %{
              commande: toPrint_list
            })

            {:noreply, remain_list}

          true ->
            {:noreply, state}
        end
      end

      def amLive?(topic) do
        presence_list = Presence.list(topic)

        case presence_list["departement:#{departement}"] do
          nil -> false
          _ -> true
        end
      end
    end
  end
end
