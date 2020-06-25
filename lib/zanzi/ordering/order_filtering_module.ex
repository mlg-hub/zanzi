defmodule Zanzibloc.Ordering.FilterModule do
  import Ecto.Query
  import Ecto.Changeset
  alias Zanzi.Repo

  def filter_by_date(date, dpt_id) do
    # {:ok, date} = NaiveDateTime.new(Date.from_iso8601!(date), ~T[00:00:00])
    # IO.inspect(date)
    {:ok, date} = Date.from_iso8601(date)

    #  fragment("?::date", od.inserted_at)

    {:ok, pending_pid} = Task.Supervisor.start_link()
    {:ok, paid_pid} = Task.Supervisor.start_link()
    {:ok, voided_pid} = Task.Supervisor.start_link()
    {:ok, unpaid_pid} = Task.Supervisor.start_link()
    {:ok, compl_pid} = Task.Supervisor.start_link()

    pending =
      Task.Supervisor.async(pending_pid, fn ->
        get_department_stats_by_cat(date, "pending", dpt_id)
      end)

    paid =
      Task.Supervisor.async(paid_pid, fn ->
        get_department_stats_by_cat(date, "paid", dpt_id)
      end)

    unpaid =
      Task.Supervisor.async(unpaid_pid, fn ->
        get_department_stats_by_cat(date, "unpaid", dpt_id)
      end)

    compl =
      Task.Supervisor.async(compl_pid, fn ->
        get_department_stats_by_cat(date, "complementary", dpt_id)
      end)

    voided =
      Task.Supervisor.async(voided_pid, fn ->
        get_department_stats_by_cat(date, "voided", dpt_id)
      end)

    pendingT = Task.await(pending)
    paidT = Task.await(paid)
    complementaryT = Task.await(compl)
    unpaidT = Task.await(unpaid)
    voidedT = Task.await(voided)

    %{
      "pending" => pendingT,
      "paid" => paidT,
      "complementary" => complementaryT,
      "unpaid" => unpaidT,
      "voided" => voidedT
    }
  end

  def filter_by_date(:order, date, order_type) do
    # {:ok, date} = NaiveDateTime.new(Date.from_iso8601!(date), ~T[00:00:00])
    {:ok, date} = Date.from_iso8601(date)
    IO.puts(order_type)

    case order_type do
      "incomplete" ->
        query =
          Order
          |> where(
            [o],
            fragment("?::date", o.inserted_at) == ^date and o.status == ^order_type and
              o.total > 0
          )
          |> join(:inner, [o], p in assoc(o, :payments))
          |> preload([o, p], payments: p)

        Repo.all(query)

      "paid" ->
        query =
          Order
          |> where(
            [od],
            od.status == ^order_type and fragment("?::date", od.inserted_at) == ^date
          )
          |> join(:inner, [od], p in assoc(od, :payments))
          |> order_by([od, p], desc: p.inserted_at)
          |> preload([od, p], payments: p)

        Repo.all(query)

      "created" ->
        query =
          Order
          |> where(
            [od],
            fragment("?::date", od.inserted_at) == ^date and od.status == ^order_type and
              od.total != 0
          )

        Repo.all(query)

      "unpaid" ->
        query =
          Order
          |> where([o], fragment("?::date", o.inserted_at) == ^date and o.status == "incomplete")
          |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == "unpaid")
          |> preload([o, p], payments: p)

        Repo.all(query, preload: :owner)

      "complementary" ->
        query =
          Order
          |> where([o], fragment("?::date", o.inserted_at) == ^date and o.status == "incomplete")
          |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == "complementary")
          |> preload([o, p], payments: p)

        Repo.all(query, preload: :owner)

      "remain" ->
        query =
          Order
          |> where([o], fragment("?::date", o.inserted_at) == ^date and o.status == "incomplete")
          |> join(:left, [o], p in assoc(o, :payments))
          |> preload([o, p], payments: p)

        Repo.all(query, preload: :owner)

      _ ->
        []
    end
  end

  def filter_by_shift(%{} = attrs) do
  end

  defp process_query(target, sous_target, dpt_id) do
    query =
      Order
      |> where([o], o.status == ^target)
      |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == ^sous_target)
      |> join(:inner, [o, p], od in OrderDetail,
        on: od.order_id == o.id and od.departement_id == ^dpt_id
      )
      |> join(:inner, [o, p, od], items in Item, on: items.id == od.item_id)
      # |> preload([od, orders, items])
      # |> group_by([od], od.id)
      |> select(
        [orders, p, od, items],
        [
          map(od, [:id, :sold_price, :sold_quantity]),
          # sum(od.sold_quantity)
          map(orders, [:code, :total, :inserted_at]),
          map(items, [:name])
        ]
      )
  end

  defp process_query(target, dpt_id) do
    query =
      Order
      |> where([o], o.status == ^target)
      |> join(:inner, [o], od in OrderDetail,
        on: od.order_id == o.id and od.departement_id == ^dpt_id
      )
      |> join(:inner, [o, od], items in Item, on: items.id == od.item_id)
      # |> preload([od, orders, items])
      # |> group_by([od], od.id)
      |> select(
        [orders, od, items],
        [
          map(od, [:id, :sold_price, :sold_quantity]),
          # sum(od.sold_quantity)
          map(orders, [:code, :total, :inserted_at]),
          map(items, [:name])
        ]
      )
  end

  defp process_query(:date, date, target, sous_target, dpt_id) do
    query =
      Order
      |> where(
        [o],
        o.status == ^target and
          (fragment("?::date", o.inserted_at) == ^date or
             fragment("?::date", o.updated_at) == ^date)
      )
      |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == ^sous_target)
      |> join(:inner, [o, p], od in OrderDetail,
        on: od.order_id == o.id and od.departement_id == ^dpt_id
      )
      |> join(:inner, [o, p, od], items in Item, on: items.id == od.item_id)
      # |> preload([od, orders, items])
      # |> group_by([od], od.id)
      |> select(
        [orders, p, od, items],
        [
          map(od, [:id, :sold_price, :sold_quantity]),
          # sum(od.sold_quantity)
          map(orders, [:code, :total, :inserted_at]),
          map(items, [:name])
        ]
      )
  end

  defp process_query(:date, date, target, dpt_id) do
    query =
      Order
      |> where(
        [o],
        o.status == ^target and
          (fragment("?::date", o.inserted_at) == ^date or
             fragment("?::date", o.updated_at) == ^date)
      )
      |> join(:inner, [o], od in OrderDetail,
        on: od.order_id == o.id and od.departement_id == ^dpt_id
      )
      |> join(:inner, [o, od], items in Item, on: items.id == od.item_id)
      # |> preload([od, orders, items])
      # |> group_by([od], od.id)
      |> select(
        [orders, od, items],
        [
          map(od, [:id, :sold_price, :sold_quantity]),
          # sum(od.sold_quantity)
          map(orders, [:code, :total, :inserted_at]),
          map(items, [:name])
        ]
      )
  end

  defp get_department_stats_by_cat(cat, dpt_id) do
    case cat do
      "paid" ->
        query = process_query("paid", dpt_id)
        format_dpt_with_query(query)

      "pending" ->
        query = process_query("created", dpt_id)
        format_dpt_with_query(query)

      "voided" ->
        query = process_query("voided", dpt_id)
        format_dpt_with_query(query)

      "unpaid" ->
        query = process_query("incomplete", "unpaid", dpt_id)
        format_dpt_with_query(query)

      "complementary" ->
        query = process_query("incomplete", "complementary", dpt_id)
        format_dpt_with_query(query)

      _ ->
        []
    end
  end

  defp get_department_stats_by_cat(date, cat, dpt_id) do
    case cat do
      "paid" ->
        query = process_query(:date, date, "paid", dpt_id)
        format_dpt_with_query(query)

      "pending" ->
        query = process_query(:date, date, "created", dpt_id)
        format_dpt_with_query(query)

      "voided" ->
        query = process_query(:date, date, "voided", dpt_id)
        format_dpt_with_query(query)

      "unpaid" ->
        query = process_query(:date, date, "incomplete", "unpaid", dpt_id)
        format_dpt_with_query(query)

      "complementary" ->
        query = process_query(:date, date, "incomplete", "complementary", dpt_id)
        format_dpt_with_query(query)

      _ ->
        []
    end
  end

  def get_department_stats(dpt_id) do
    {:ok, pending_pid} = Task.Supervisor.start_link()
    {:ok, paid_pid} = Task.Supervisor.start_link()
    {:ok, voided_pid} = Task.Supervisor.start_link()
    {:ok, unpaid_pid} = Task.Supervisor.start_link()
    {:ok, compl_pid} = Task.Supervisor.start_link()

    pending =
      Task.Supervisor.async(pending_pid, fn ->
        get_department_stats_by_cat("pending", dpt_id)
      end)

    paid =
      Task.Supervisor.async(paid_pid, fn ->
        get_department_stats_by_cat("paid", dpt_id)
      end)

    unpaid =
      Task.Supervisor.async(unpaid_pid, fn ->
        get_department_stats_by_cat("unpaid", dpt_id)
      end)

    compl =
      Task.Supervisor.async(compl_pid, fn ->
        get_department_stats_by_cat("complementary", dpt_id)
      end)

    voided =
      Task.Supervisor.async(voided_pid, fn ->
        get_department_stats_by_cat("voided", dpt_id)
      end)

    pendingT = Task.await(pending)
    paidT = Task.await(paid)
    complementaryT = Task.await(compl)
    unpaidT = Task.await(unpaid)
    voidedT = Task.await(voided)

    %{
      "pending" => pendingT,
      "paid" => paidT,
      "complementary" => complementaryT,
      "unpaid" => unpaidT,
      "voided" => voidedT
    }
  end

  def format_dpt_with_query(query) do
    {:ok, dptArray} = Agent.start_link(fn -> [] end)
    {:ok, count} = Agent.start_link(fn -> 1 end)

    Repo.all(query)
    |> Enum.map(fn [od, o, i] = elts ->
      if o != nil and elts != nil do
        {
          i.name,
          %{
            "sold_price" => od.sold_price,
            "sold_quantity" => od.sold_quantity,
            "order_code" => o.code,
            "order_time" => o.inserted_at,
            "item_name" => i.name,
            "id" => Agent.get_and_update(count, fn state -> {state, state + 1} end)
          }
        }
      end
    end)
    |> Enum.map(fn {_k, v} ->
      # if exit update otherwise insert
      # if Enum.member?(Agent.get(itemsArray, fn list -> list end), v) do
      my_list = Agent.get(dptArray, fn list -> list end)

      index =
        Enum.find_index(my_list, fn x ->
          x["item_name"] == v["item_name"] and x["sold_price"] == v["sold_price"]
        end)

      case index do
        nil ->
          Agent.update(dptArray, fn list -> [v | list] end)

        _ ->
          val = Enum.at(my_list, index)

          new_map =
            Map.get_and_update(val, "sold_quantity", fn current_val ->
              {current_val, current_val + v["sold_quantity"]}
            end)

          {_, correct_map} = new_map

          map_with_orders_list =
            Map.get_and_update(correct_map, "order_code", fn cv ->
              {cv, List.flatten([cv] ++ [v["order_code"]])}
            end)

          {_, my_clean_map} = map_with_orders_list
          Agent.update(dptArray, fn list -> List.replace_at(list, index, my_clean_map) end)
      end

      # else
      # end
    end)

    data = Agent.get(dptArray, fn list -> list end)
    Agent.stop(dptArray)
    Agent.stop(count)
    data
  end
end
