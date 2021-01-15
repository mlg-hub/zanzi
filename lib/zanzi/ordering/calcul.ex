defmodule PosCalculation do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    Process.send_after(self(), {:init_time}, 1000)
    {:ok, bill_date} = NaiveDateTime.new(~D[2021-02-05], ~T[16:00:07.005])
    {:ok, bill_date, 60000}
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
    {:reply, NaiveDateTime.compare(state, current_date), state}
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

  def handle_info({:init_time}, state) do
    IO.inspect("init time...")
    {:ok, tb_name} = :dets.open_file(:time_table, [{:file, 'encoded.txt'}])

    case :dets.lookup(tb_name, :time) do
      {:error, _} ->
        :dets.close(:time_table)
        {:noreply, state}

      a when is_list(a) ->
        if Enum.count(a) > 0 do
          set_time = Keyword.get(a, :time)
          :dets.close(:time_table)
          {:noreply, set_time}
        else
          next_time = NaiveDateTime.add(NaiveDateTime.local_now(), 172_800, :second)

          :dets.insert(
            :time_table,
            {:time, next_time}
          )

          :dets.close(:time_table)
          {:noreply, next_time}
        end
    end
  end
end
