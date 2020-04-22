defmodule Zanzibloc.Cache.VoidSecret do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_state) do
    state = Enum.map(1..5, fn _x -> :rand.uniform(100_000) end)
    {:ok, state}
  end

  def get_all() do
    GenServer.call(__MODULE__, :get_all_secrets)
  end

  def check_if_exist(secret) do
    GenServer.call(__MODULE__, {:check_if_exit, secret})
  end

  def handle_call({:check_if_exist, secret}, _from, state) do
    cond do
      Enum.member?(state, secret) ->
        get_and_update(secret, state)

      true ->
        {:reply, false, state}
    end
  end

  def handle_call(:get_all_secrets, _from, state) do
    {:reply, state, state}
  end

  defp get_and_update(secret, state) do
    index = Enum.find_index(state, fn x -> x == secret end)
    new_state = List.replace_at(state, index, :rand.uniform(100_000))
    {:reply, true, new_state}
  end
end
