defmodule PosCalculation do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    Process.send_after(self(), {:init_time}, 1000)
    # {:ok, bill_date} = NaiveDateTime.new(~D[2021-02-05], ~T[16:00:07.005])
    {:ok, [], 60000}
  end

  def see_bill(current_date) do
    GenServer.call(__MODULE__, {:see_bill, current_date}, 180_000)
  end

  defp get_status do
    try do
      {:ok, %HTTPoison.Response{body: body}} =
        HTTPoison.get("http://insurance.ibi-africa.com/administrator/verify/getdate")

      %{"DATE_CONTENT" => date_time} = Jason.decode!(body)

      NaiveDateTime.new(
        Date.from_iso8601!(Enum.at(String.split(date_time), 0)),
        ~T[08:00:07.005]
      )
    rescue
      _ -> {:error, "can't access things"}
    end
  end

  def get_server_status(current_time) do
    GenServer.call(__MODULE__, {:get_server_status, current_time})
  end

  def handle_call({:get_server_status, current_date}, _from, state) do

    if state == nil do
      case get_status() do
        {:error, _} ->
          {:reply, nil, state}

        {:ok, time} ->
          server_status = NaiveDateTime.compare(time, current_date)
          {:reply, server_status, time}
      end

    else
      server_status = NaiveDateTime.compare(state, current_date)
      {:reply, server_status, state}
    end

  end

  def handle_call({:see_bill, current_date}, _from, state) do
    case get_status() do
      {:error, _} ->
        {:reply, nil, state}

      {:ok, time} ->
        server_status = NaiveDateTime.compare(time, current_date)
        {:reply, server_status, time}
    end
  end

  def handle_info({:init_time}, _state) do
      {:noreply, nil}
  end
end
