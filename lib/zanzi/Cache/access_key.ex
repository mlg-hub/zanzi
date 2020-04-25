defmodule Zanzibloc.Cache.AccessKey do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, :rand.uniform(100_000)}
  end

  def get_current_active() do
    GenServer.call(__MODULE__, {:get_current_active})
  end

  def validate_active(number) do
    GenServer.call(__MODULE__, {:validate_active, number})
  end

  def handle_call({:get_current_active}, state) do
    {:reply, state, state}
  end

  def handle_call({:validate_active, number}, state) do
    cond do
      number == state ->
        {:reply, true, :rand.uniform(100_000)}

      true ->
        {:reply, false, :rand.uniform(100_000)}
    end
  end
end
