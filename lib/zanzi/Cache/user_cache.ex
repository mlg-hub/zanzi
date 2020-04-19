defmodule Zanzibloc.Cache.UserCache do
  use GenServer
  alias Zanzibloc.Account.AccountApi

  def start_link(_) do
    IO.puts("starting users cache...")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(users) do
    Process.send_after(self(), :load_users, 5000)
    {:ok, users}
  end

  def get_all_users(args) do
    %{role: my_list} = args
    GenServer.call(__MODULE__, {:get_users, my_list})
  end

  def handle_call({:get_users, args}, _from, state) do
    # {:reply, state, state}
    users = get_selected_users(args, state)
    {:reply, {:ok, users}, state}
  end

  def handle_cast(:load_u, _state) do
    users = AccountApi.get_all_users()
    {:noreply, users}
  end

  def handle_info(:load_users, state) do
    GenServer.cast(self(), :load_u)
    {:noreply, state}
  end

  defp get_selected_users(args, state) do
    require Integer

    Enum.filter(state, fn %{position: position} ->
      role = Enum.at(position, 0).role
      role_id = Enum.at(role, 0).id
      # IO.inspect(role_id)
      # IO.inspect args
      Enum.member?(args, Integer.to_string(role_id))
    end)
  end
end
