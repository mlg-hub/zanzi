defmodule Zanzibloc.Cache.PrintBluePrint do
  defmacro __using__(opts) do
    {:ok, departement} = Keyword.fetch(opts, :departement)
    {:ok, module} = Keyword.fetch(opts, :module)

    quote do
      use GenServer
      alias ZanziWeb.Presence

      def start_link(_) do
        IO.puts("starting ...to print #{unquote(departement)}")
        GenServer.start_link(unquote(module), nil, name: unquote(module))
      end

      def init(_) do
        {:ok, %{toPrint: [], cache: [], count: 0}}
      end

      def update_cache(items) do
        IO.puts("update cache due to fetching....")
        GenServer.cast(unquote(module), {:update_cache, items})
      end

      def update_cache_from_manual(payload) do
        GenServer.cast(unquote(module), {:manual_update, payload})
      end

      def add_new(items) do
        GenServer.cast(unquote(module), {:add_new_item, items})
      end

      def fetch_pending_print() do
        GenServer.call(unquote(module), :fetch_pending)
      end

      def fetch_cache_print() do
        GenServer.call(unquote(module), :fetch_cache_print)
      end

      def get_my_state() do
        GenServer.call(unquote(module), :get_my_state)
      end

      def handle_call(:get_my_state, _from, state) do
        {:reply, state, state}
      end

      def handle_cast({:update_cache, items}, state) when is_list(items) do
        IO.puts("am updating the cache.....")
        IO.inspect(items)
        IO.puts("am counts...")

        counts =
          Enum.map(items, fn x ->
            IO.puts("mtototototototttt is my map...")
            IO.inspect(x)
            Keyword.get(x, :count)
          end)

        IO.inspect(counts)

        new_cache =
          Enum.reject(state.cache, fn item ->
            Enum.member?(counts, Keyword.get(item, :count))
          end)

        new_cache = Enum.reject(new_cache, fn x -> Enum.count(x) == 0 end)
        {:noreply, %{state | cache: new_cache}}
      end

      def handle_cast({:manual_update, %{"commande" => payload}}, state) do
        transfrom_cache =
          Enum.map(state.cache, fn x ->
            Enum.drop(x, -1)
          end)

        new_cache =
          Enum.reject(transfrom_cache, fn x ->
            Enum.any?(payload, fn p ->
              p1 =
                Enum.map(p, fn %{
                                 "code" => code,
                                 "item_name" => name,
                                 "item_price" => price,
                                 "order_id" => id,
                                 "order_time" => time,
                                 "owner_name" => owner,
                                 "owner_username" => username,
                                 "quantity" => qty
                               } ->
                  %{
                    code: code,
                    item_name: name,
                    item_price: price,
                    order_id: id,
                    order_time: time,
                    owner_name: owner,
                    owner_username: username,
                    quantity: qty
                  }
                end)

              p1 == x
            end)
          end)

        new_cache = Enum.reject(new_cache, fn x -> Enum.count(x) == 0 end)
        # {:noreply, %{state | cache: new_cache}}
        {:noreply, %{state | cache: new_cache}}
      end

      def handle_cast({:add_new_item, items}, state) do
        make_active = items ++ [count: state.count]
        new_state_print = Map.update(state, :toPrint, state.toPrint, &(&1 ++ [make_active]))

        make_active = items ++ [count: state.count]
        new_state_print = Map.update(new_state_print, :cache, state.cache, &(&1 ++ [make_active]))
        Process.send_after(self(), :print_to_dpt, 2000)
        {:noreply, %{new_state_print | count: state.count + 1}}
      end

      def handle_call(:fetch_pending, _from, state) do
        {toPrint, remain} = Enum.split(state.toPrint, 10)
        new_state = %{state | toPrint: remain}
        Process.send_after(self(), {:clear_cache, toPrint}, 3000)

        cond do
          Enum.count(toPrint) > 0 ->
            good_print =
              Enum.map(toPrint, fn x ->
                Enum.drop(x, -1)
              end)

            {:reply, good_print, new_state}

          true ->
            {:reply, [], new_state}
        end
      end

      def handle_call(:fetch_cache_print, _from, state) do
        cond do
          Enum.count(state.cache) > 0 ->
            good_print =
              Enum.map(state.cache, fn x ->
                Enum.drop(x, -1)
              end)

            {:reply, good_print, %{state | cache: []}}

          true ->
            {:reply, [], state}
        end
      end

      def handle_info({:clear_cache, items}, state) do
        IO.puts("in handle info")
        IO.inspect(items)
        update_cache(items)
        {:noreply, state}
      end

      def handle_info(:print_to_dpt, state) do
        isLive = amLive?("departement:zanzi")
        {toPrint_list, remain_list} = Enum.split(state.toPrint, 10)

        good_print =
          Enum.map(toPrint_list, fn x ->
            Enum.drop(x, -1)
          end)

        IO.puts("hey am")

        cond do
          isLive ->
            ZanziWeb.Endpoint.broadcast!("commande:#{unquote(departement)}", "printpaper", %{
              commande: good_print
            })

            new_state = %{state | toPrint: remain_list}

            {:noreply, new_state}

          true ->
            {:noreply, state}
        end
      end

      def amLive?(topic) do
        presence_list = Presence.list(topic)

        case presence_list["departement:#{unquote(departement)}"] do
          nil -> false
          _ -> true
        end
      end
    end
  end
end
