defmodule PosCalculation do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:ok, bill_date} = NaiveDateTime.new(~D[2021-02-05], ~T[16:00:07.005])
    {:ok, bill_date}
  end

  def see_bill(current_date) do
    GenServer.call(__MODULE__, {:see_bill, current_date})
  end

  def handle_call({:see_bill, current_date}, _from, state) do
    {:reply, NaiveDateTime.compare(state, current_date), state}
  end
end
