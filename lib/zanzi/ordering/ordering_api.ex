defmodule Zanzibloc.Ordering.OrderingApi do
  @moduledoc """
  The Ordering context.
  """

  import Ecto.Query, warn: false
  alias Zanzi.Repo
  require Logger

  alias Zanzibloc.Ordering.{
    Order,
    OrderDetail,
    OrderPayment,
    OrderOwner,
    TableOrders,
    Table,
    OrderSplit,
    OrderMerged
  }

  alias Zanzibloc.Menu.Item
  alias Zanzibloc.Account.User

  def list_orders do
    Repo.all(Order)
  end

  def get_all_tables do
    Repo.all(Table)
  end

  def void_order(order_id) do
    order = Repo.get(Order, order_id)

    case order do
      %Order{} = result_order ->
        void_my_order(result_order)

      _ ->
        %{error: "order not found"}
    end
  end

  defp void_my_order(order) do
    changeset = order |> Order.update_changeset(%{status: "voided"})

    case Repo.update(changeset) do
      {:ok, _} -> %{status: "success"}
      _ -> %{error: "cant void the order"}
    end
  end

  def get_order!(id), do: Repo.get!(Order, id)

  def get_items(route) do
    case route do
      :bar ->
        query = from i in Item, where: i.departement_id == 1
        Repo.all(query)

      :kitchen ->
        query = from i in Item, where: i.departement_id == 2
        Repo.all(query)

      :coffee ->
        query = from i in Item, where: i.departement_id == 3
        Repo.all(query)

      :restaurant ->
        query = from i in Item, where: i.departement_id == 5
        Repo.all(query)

      :mini_bar ->
        query = from i in Item, where: i.departement_id == 6
        Repo.all(query)

      _ ->
        []
    end
  end

  def send_transfer_request(%{order: order, transfer: transfer_to}) do
    order_to_transfer = Repo.get_by!(OrderOwner, %{order_id: order})
    IO.inspect(order_to_transfer)

    with %OrderOwner{} = order <- order_to_transfer do
      IO.inspect(order)

      order
      |> OrderOwner.transfer_request_changeset(%{transfer_to: transfer_to, status: "requested"})
      |> Repo.update()
    end
  end

  def reject_transfer_request(%{order: order}) do
    order_to_reject = Repo.get_by!(OrderOwner, %{order_id: order})

    with %OrderOwner{} = order <- order_to_reject do
      order
      |> OrderOwner.reject_request_changeset(%{status: "committed", transfer_to: ""})
      |> Repo.update()
    end
  end

  def accept_transfer_request(%{order: order}) do
    order_to_accept = Repo.get_by!(OrderOwner, %{order_id: order})

    with %OrderOwner{} = order <- order_to_accept do
      order
      |> OrderOwner.accept_request_changeset(%{
        status: "accepted",
        from_owner: order.current_owner,
        transfer_to: "",
        current_owner: order.transfer_to
      })
      |> Repo.update()
    end
  end

  def create_empty_split(attrs) do
    attrs = Map.put(attrs, :filled, 0)
    IO.inspect(attrs)

    split_changeset =
      %Order{}
      |> Order.create_split_changeset(attrs)

    IO.puts("my spliiiiiiiiiiiiiit")
    IO.inspect(split_changeset)

    case split_changeset.valid? do
      true ->
        case Repo.insert!(split_changeset) do
          %Order{} = order ->
            owner_attrs = %{current_owner: Map.get(attrs, :user_id), order_id: order.id}
            owner_changeset = %OrderOwner{} |> OrderOwner.changeset(owner_attrs)

            with %OrderOwner{} <- Repo.insert!(owner_changeset) do
              %{status: "split success"}
            end

          _ ->
            {:error, "Could not split"}
        end

      _ ->
        %{message: "your changeset is invalid"}
    end
  end

  def update_split_order(%{order_id: order_id, splitted_order: splitted} = attrs) do
    attrs = Map.update(attrs, :items, [], &build_items/1)
    splitted_order = Repo.get(Order, splitted)

    total =
      Enum.reduce(
        Map.get(attrs, :items),
        0,
        fn %{sold_quantity: qty, sold_price: p}, acc -> qty * p + acc end
      )

    # attrs = Map.put(attrs, :total, total)
    split_changeset =
      splitted_order
      |> Order.update_split_changeset(%{total: total, filled: 1, splitted_from: order_id})
      |> Repo.update()

    with {:ok, order} <- split_changeset do
      Enum.each(attrs.items, fn x ->
        IO.inspect(x)

        %OrderDetail{}
        |> OrderDetail.changeset(Map.put(x, :order_id, order.id))
        |> Repo.insert!()
      end)

      mutate_order(order_id, attrs.items, total)

      %{status: "success"}
    end
  end

  def create_order(attrs \\ %{}) do
    #  item = %{id, quantity}

    attrs = Map.update(attrs, :items, [], &build_items/1)

    total =
      Enum.reduce(
        Map.get(attrs, :items),
        0,
        fn %{sold_quantity: qty, sold_price: p}, acc ->
          IO.inspect(qty)
          IO.inspect(p)
          qty * p + acc
        end
      )

    attrs = Map.put(attrs, :total, total)

    save_changeset =
      %Order{}
      |> Order.changeset(attrs)

    case Repo.insert!(save_changeset) do
      %Order{} = order ->
        owner_attrs = %{current_owner: Map.get(attrs, :user_id), order_id: order.id}
        owner_changeset = %OrderOwner{} |> OrderOwner.changeset(owner_attrs)

        with %OrderOwner{} = boss <- Repo.insert!(owner_changeset) do
          saved_bon_commande =
            Enum.map(attrs.items, fn x ->
              changeset =
                %OrderDetail{}
                |> OrderDetail.changeset(Map.put(x, :order_id, order.id))

              case Repo.insert!(changeset) do
                %OrderDetail{} = order_detail ->
                  query =
                    OrderDetail
                    |> where([detail], detail.id == ^order_detail.id)
                    |> join(:left, [detail], order in assoc(detail, :order))
                    |> join(:left, [detail, order], item in ^Item, on: item.id == detail.item_id)
                    |> join(:left, [detail, order, item], owner in assoc(order, :owner))
                    # |> select([detail, _, _, _], %{detail_info: detail.id})
                    |> preload([detail, order, item, owner],
                      order: {order, owner: owner},
                      item: item
                    )
                    |> Repo.one()

                  # IO.inspect(query)
                  %{query: query, update: nil}

                _ ->
                  %{}
              end
            end)

          {:ok, %{order: order, details: saved_bon_commande}}
        end

      _ ->
        {:error, save_changeset}
    end
  end

  def update_order(order_id, attrs \\ %{}) do
    attrs = Map.update(attrs, :items, [], &build_items/1)
    main_order = Repo.get(Order, order_id)

    total =
      Enum.reduce(
        Map.get(attrs, :items),
        0,
        fn %{sold_quantity: qty, sold_price: p}, acc ->
          IO.inspect(qty)
          IO.inspect(p)
          qty * p + acc
        end
      )

    main_order_changeset =
      main_order |> Order.add_item_changeset(%{total: main_order.total + total})

    with {:ok, main_returned_order} <- Repo.update(main_order_changeset) do
      saved_bon_commande =
        Enum.map(attrs.items, fn x ->
          exist =
            Repo.get_by(OrderDetail, %{order_id: main_returned_order.id, item_id: x.item_id})

          changeset =
            %OrderDetail{}
            |> OrderDetail.changeset(Map.put(x, :order_id, main_order.id))

          case exist do
            nil ->
              case Repo.insert!(changeset) do
                %OrderDetail{} = order_detail ->
                  query =
                    OrderDetail
                    |> where([detail], detail.id == ^order_detail.id)
                    |> join(:left, [detail], order in assoc(detail, :order))
                    |> join(:left, [detail, order], item in ^Item, on: item.id == detail.item_id)
                    |> join(:left, [detail, order, item], owner in assoc(order, :owner))
                    # |> select([detail, _, _, _], %{detail_info: detail.id})
                    |> preload([detail, order, item, owner],
                      order: {order, owner: owner},
                      item: item
                    )
                    |> Repo.one()

                  # IO.inspect(query)
                  %{query: query, update: nil}

                _ ->
                  %{}
              end

            %OrderDetail{} = order_d ->
              changeset =
                order_d
                |> OrderDetail.changeset(
                  Map.put(x, :sold_quantity, order_d.sold_quantity + x.sold_quantity)
                )

              case Repo.update(changeset) do
                {:ok, order_detail} ->
                  query =
                    OrderDetail
                    |> where([detail], detail.id == ^order_detail.id)
                    |> join(:left, [detail], order in assoc(detail, :order))
                    |> join(:left, [detail, order], item in ^Item, on: item.id == detail.item_id)
                    |> join(:left, [detail, order, item], owner in assoc(order, :owner))
                    # |> select([detail, _, _, _], %{detail_info: detail.id})
                    |> preload([detail, order, item, owner],
                      order: {order, owner: owner},
                      item: item
                    )
                    |> Repo.one()

                  # IO.inspect(query)
                  %{query: query, update: x}

                _ ->
                  %{}
              end
          end
        end)

      Logger.info("zzazazazzzzzzzzzzzzzzzzzzzzzzzzzzz")
      IO.inspect(saved_bon_commande)
      {:ok, %{order: main_returned_order, details: saved_bon_commande}}
    end
  end

  def create_payment(attrs \\ %{}) do
    case Repo.get(Order, Map.get(attrs, :order_id)) do
      %Order{} = order ->
        attrs = Map.put(attrs, :order_total, order.total)
        total_amount = order.total
        total_paid = Map.get(attrs, :order_paid)

        payments =
          %OrderPayment{}
          |> OrderPayment.changeset(attrs)
          |> Repo.insert!()

        case payments do
          %OrderPayment{} = payments ->
            with %{order_id: order_id} <- attrs do
              case Repo.get(Order, order_id) do
                %Order{} = order ->
                  cond do
                    total_paid < total_amount ->
                      case update_order_clearance(order, %{status: "incomplete"}) do
                        nil -> {:error, "error occured"}
                        _ -> {:ok, %{payment: "success"}}
                      end

                    total_paid == total_amount ->
                      case update_order_clearance(order, %{status: "paid"}) do
                        nil -> {:error, "error occured"}
                        _ -> {:ok, %{payment: "success"}}
                      end

                    total_paid > total_amount ->
                      case update_order_clearance(order, %{status: "paid"}) do
                        nil -> {:error, "error occured"}
                        _ -> {:ok, %{payment: "success"}}
                      end

                    true ->
                      {:error, "Error in amount"}
                  end

                _ ->
                  {:error, "error occured"}
              end
            end

          _ ->
            {:error, "error occured"}
        end

      _ ->
        {:error, "payment not made"}
    end
  end

  defp build_items(items) do
    for item <- items do
      menu_item = Zanzibloc.Menu.MenuApi.get_item!(item.id)

      %{
        item_id: item.id,
        departement_id: menu_item.departement_id,
        category_id: menu_item.category_id,
        name: menu_item.name,
        sold_quantity: item.quantity,
        sold_price: menu_item.price
      }
    end
  end

  def save_ownership(attrs \\ %{}) do
    ownership =
      %OrderOwner{}
      |> OrderOwner.changeset(attrs)

    case Repo.insert!(OrderOwner, ownership) do
      %OrderOwner{} = orderOwner ->
        {:ok, %{message: "new boss created"}}

      _ ->
        {:error, "Error occured"}
    end
  end

  def transfert_ownership(attrs \\ %{}) do
  end

  def update_order_clearance(%Order{} = order, attrs) do
    order
    |> Order.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_order(%Order{} = order) do
    Repo.delete(order)
  end

  def change_order(%Order{} = order) do
    Order.changeset(order, %{})
  end

  defp orders_query(args) do
    # query is the Item
    Enum.reduce(args, Item, fn
      {:order, order}, query ->
        query |> order_by({^order, :name})

      {:filter, filter}, query ->
        query |> filter_with(filter)
    end)
  end

  defp filter_with(query, filter) do
    Enum.reduce(filter, query, fn
      {:name, name}, query ->
        from(q in query, where: ilike(q.name, ^"%#{name}%"))

      {:priced_above, price}, query ->
        from(q in query, where: q.price >= ^price)

      {:priced_below, price}, query ->
        from(q in query, where: q.price <= ^price)

      {:added_after, date}, query ->
        from(q in query, where: q.added_on >= ^date)

      {:added_before, date}, query ->
        from(q in query, where: q.added_on <= ^date)

      {:category, category_name}, query ->
        from(q in query,
          join: c in assoc(q, :category),
          where: ilike(c.name, ^"%#{category_name}%")
        )

      {:tag, tag_name}, query ->
        from(q in query,
          join: t in assoc(q, :tags),
          where: ilike(t.name, ^"%#{tag_name}%")
        )
    end)
  end

  def get_all_split_bill_for_user(username) do
    user = Repo.get_by(User, %{username: username})

    query =
      User
      |> where([u], u.id == ^user.id)
      |> join(:left, [u], orders in assoc(u, :orders),
        on: orders.filled == 0 and not is_nil(orders.table_id)
      )
      |> join(:left, [u, orders], table in Table, on: orders.table_id == table.id)
      |> order_by([u, orders, table], asc: orders.ordered_at)
      |> preload([u, orders, table], orders: {orders, table: table})

    Repo.all(query)
  end

  def get_order_details_html(id) do
    # order = Repo.get(Order, id)

    query =
      Order
      |> where([o], o.id == ^id)
      |> join(:left, [o], details in assoc(o, :order_details))
      |> join(:left, [o, details], table in Table, on: o.table_id == table.id)
      |> join(:left, [o, details, table], items in assoc(details, :item))
      |> join(:left, [o, details, table, items], payments in assoc(o, :payments))
      |> join(:left, [o, details, table, items], owner in assoc(o, :owner))
      |> preload([o, details, table, items, payments, owner],
        order_details: {details, item: items},
        owner: owner,
        table: table,
        payments: payments
      )

    Repo.one(query)
  end

  def set_printed(order_id) do
    # order = Repo.get(Order, order_id)
    case Repo.get(Order, order_id) do
      %Order{} = order ->
        order
        |> Order.update_changeset(%{print_status: 1})
        |> Repo.update()

      _ ->
        {:error, "order does not exist"}
    end
  end

  def get_all_orders_from_waiter(username) do
    user = Repo.get_by(User, %{username: username})

    query =
      User
      |> where([u], u.id == ^user.id)
      |> join(:left, [u], orders in assoc(u, :orders),
        on:
          orders.status == "created" and
            (orders.merged_status == 0 or
               orders.merged_status == 1) and
            (orders.filled == 1 and (not is_nil(orders.total) or orders.total == 0))
      )
      |> order_by([u, orders], asc: orders.ordered_at)
      # |> limit([u, orders], 1)
      |> join(:left, [u, orders], details in assoc(orders, :order_details))
      |> join(:left, [u, orders, details], table in Table, on: orders.table_id == table.id)
      |> join(:left, [u, orders, details, table], items in assoc(details, :item))
      |> join(:left, [u, orders, details, table, items], payments in assoc(orders, :payments))
      |> preload([u, orders, details, table, items, payments],
        orders: {orders, order_details: {details, item: items}, table: table, payments: payments}
      )

    Repo.one(query)
  end

  def get_cleared_bill(date, user_id) do
    {:ok, date} = Date.from_iso8601(date)

    query =
      OrderPayment
      |> where([p], p.user_id == ^user_id)
      |> join(:inner, [p], o in assoc(p, :order), on: o.status == "paid")
      |> join(:inner, [p, o], pd in assoc(o, :payments),
        on: fragment("?::date", pd.inserted_at) == ^date
      )
      |> order_by([p, o, pd], desc: pd.inserted_at)
      # |> join(:left, [p, o], d in assoc(o, :order_details))
      |> preload([p, o], order: o)

    Repo.all(query)
  end

  def get_bill(filter) do
    case filter do
      :pending ->
        query = Order |> where([o], o.status == "created")

        Repo.all(query, preload: :owner)

      :voided ->
        query = Order |> where([o], o.status == "voided")

        Repo.all(query, preload: :owner)

      :cleared ->
        query = Order |> where([o], o.status == "paid")
        Repo.all(query, preload: :owner)

      :incomplete ->
        query =
          Order
          |> where([o], o.status == "incomplete")
          |> join(:left, [o], p in assoc(o, :payments))
          |> preload([o, p], payments: p)

        Repo.all(query, preload: :owner)

      _ ->
        []
    end
  end

  def get_pending_bill() do
    query = from o in Order, where: o.status == "created"
    Repo.all(query)
  end

  def get_order_details(order_id) do
    case Repo.get(Order, order_id) do
      %Order{} = order ->
        case order.merged_status do
          0 -> Repo.preload(order, :order_details)
          1 -> display_merged_bill(order.id)
        end

      _ ->
        {:error, "order does not exist"}
    end
  end

  def get_sales_stats(date, user_id) do
    {:ok, kitchen} = Agent.start_link(fn -> 0 end)
    {:ok, bar} = Agent.start_link(fn -> 0 end)
    {:ok, mini_bar} = Agent.start_link(fn -> 0 end)
    {:ok, restaurant} = Agent.start_link(fn -> 0 end)

    {:ok, date_search} = Date.from_iso8601(date)
    # and fragment("?::date", p.inserted_at) == ^date
    query =
      OrderPayment
      |> where(
        [p],
        p.user_id == ^user_id and p.order_paid > 0 and
          fragment("?::date", p.inserted_at) == ^date_search
      )
      |> join(:inner, [p], order in assoc(p, :order))
      |> join(:inner, [p, order], order_details in assoc(order, :order_details))
      |> join(:inner, [p, order, od], dpt in assoc(od, :departement))
      # |> preload([p, order, order_details, dpt],
      #   order: {order, order_details: {order_details, departement: dpt}}
      # )
      |> select([p, o, od, dpt], [
        map(od, [:item_id, :sold_price, :sold_quantity]),
        # map(p, [:order_id, :order_paid, :order_total]),
        map(dpt, [:name])
      ])

    all_sales = Repo.all(query)

    # Enum.dedup(all_sales)

    Enum.each(all_sales, fn [%{sold_price: price, sold_quantity: qty}, %{name: dpt}] ->
      case String.downcase(dpt) do
        "bar" ->
          Agent.update(bar, fn acc ->
            acc + price * qty
          end)

        "kitchen" ->
          Agent.update(kitchen, fn acc ->
            acc + price * qty
          end)

        "mini bar" ->
          Agent.update(mini_bar, fn acc ->
            acc + price * qty
          end)

        "restaurant" ->
          Agent.update(restaurant, fn acc ->
            acc + price * qty
          end)
      end
    end)

    r = %{
      kitchen: Agent.get(kitchen, fn tot -> tot end),
      bar: Agent.get(bar, fn tot -> tot end),
      restaurant: Agent.get(restaurant, fn tot -> tot end),
      mini_bar: Agent.get(mini_bar, fn tot -> tot end)
    }

    Agent.stop(kitchen)
    Agent.stop(bar)
    Agent.stop(mini_bar)
    Agent.stop(restaurant)
    r
  end

  def get_pending_orders(date) do
    {:ok, date} = Date.from_iso8601(date)

    query =
      Order
      |> where([o], o.status == "created" and fragment("?::date", o.inserted_at) == ^date)
      |> preload([:owner, :table])

    Repo.all(query)
  end

  # @spec get_incomplete_orders :: any
  def get_incomplete_orders(date) do
    {:ok, date} = Date.from_iso8601(date)

    query =
      Order
      |> where([o], o.status == "incomplete" and fragment("?::date", o.updated_at) == ^date)
      |> preload([:owner, :table])

    Repo.all(query)
  end

  def get_voided_orders(date) do
    {:ok, date} = Date.from_iso8601(date)

    query =
      Order
      |> where([o], o.status == "voided" and fragment("?::date", o.updated_at) == ^date)
      |> preload([:owner, :table])

    Repo.all(query)
  end

  def order_payment_history(id) do
    query =
      Order
      |> where([o], o.id == ^id)
      |> join(:left, [o], payments in OrderPayment, on: payments.order_id == o.id)
      |> preload([o, payments], payments: payments)

    Repo.all(query)
  end

  # def split_bill(
  #       %{
  #         order_id: order_id,
  #         spliter_id: spliter_id,
  #         split_code: split_code,
  #         items: items
  #       } = attrs
  #     ) do
  #   total =
  #     Enum.reduce(
  #       Map.get(attrs, :items),
  #       0,
  #       fn %{sold_quantity: qty, sold_price: p}, acc -> qty * p + acc end
  #     )

  #   attrs = Map.put(attrs, :split_total, total)

  #   order_split =
  #     %OrderSplit{}
  #     |> OrderSplit.changeset(attrs)

  #   case Repo.insert!(order_split) do
  #     %OrderSplit{} = order_sp ->
  #       mutate_order(order_id, items, total)

  #       mutate_order_details(%{
  #         split_order: order_sp,
  #         main_order: order_id,
  #         items: Map.get(attrs, :items)
  #       })

  #     _ ->
  #       {:error, "Error occured!"}
  #   end
  # end

  def mutate_order(order_id, items, total) do
    # order_query =
    #   from(o in Zanzibloc.Ordering.Order, where: o.id == ^order_id, preload: :order_details)

    order_main = Repo.get(Order, order_id)

    order_changeset =
      Order.update_main_split_changeset(order_main, %{
        split_status: 1,
        total: order_main.total - total
      })

    # Repo.update(order_changeset)
    case Repo.update(order_changeset) do
      {:ok, order} ->
        Enum.each(items, fn %{item_id: id, sold_quantity: qty} ->
          order_detail = Repo.get_by(OrderDetail, %{order_id: order.id, item_id: id})

          with %OrderDetail{} = order_detail_return <- order_detail do
            order_detail_changeset =
              order_detail_return
              |> Ecto.Changeset.cast(%{sold_quantity: order_detail_return.sold_quantity}, [
                :sold_quantity
              ])
              |> Ecto.Changeset.put_change(
                :sold_quantity,
                order_detail_return.sold_quantity - qty
              )

            Repo.update(order_detail_changeset)
          end
        end)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp mutate_order_details(attrs) do
    Enum.each(Map.get(attrs, :items), fn %{id: id, sold_quantity: qty} ->
      nil
    end)
  end

  def merge_bills(%{main_order_id: main_order_id, user_id: user, sub_order_ids: sub_order_ids}) do
    main_order = Repo.get(Order, main_order_id)

    with %Order{} = order <- main_order do
      Enum.each(sub_order_ids, fn id ->
        # put split status to one for the main and to for the sub
        merged_changeset =
          %OrderMerged{}
          |> OrderMerged.changeset(%{
            main_order_id: main_order_id,
            user_id: user,
            sub_order_id: id
          })

        case Repo.insert!(merged_changeset) do
          %OrderMerged{} ->
            update_affected_orders(%{main_order: main_order, sub_order_id: id})
            {:ok, status: "success"}

          _ ->
            {:error, "couldnt merged the bills"}
        end

        Order
      end)

      %{status: "success"}
    else
      _ -> {:error, "Cant find main order"}
    end
  end

  def display_merged_bill(order_id) do
    Order
    |> where([o], o.id == ^order_id)
    |> join(:left, [o], main_detail in assoc(o, :order_details))
    |> join(:left, [o, main_detail], merged_orders in OrderMerged,
      on: merged_orders.main_order_id == o.id
    )
    |> join(:left, [o, main_detail, merged_orders], sub_order in assoc(merged_orders, :sub_order))
    |> join(
      :left,
      [o, main_detail, merged_orders, sub_order],
      sub_orders_details in OrderDetail,
      on: sub_orders_details.order_id == merged_orders.sub_order_id
    )
    |> join(
      :left,
      [o, main_detail, merged_orders, sub_order, sub_orders_details],
      items_main in assoc(main_detail, :item)
    )
    |> join(
      :left,
      [o, main_detail, merged_orders, sub_order, sub_orders_details, items_main],
      items in assoc(sub_orders_details, :item)
    )
    |> preload([o, main_detail, merged_orders, sub_order, sub_orders_details, items_main, items],
      order_details: {main_detail, item: items_main},
      mergings:
        {merged_orders,
         sub_order: sub_order, order_merged_detail: {sub_orders_details, item: items}}
    )
    |> Repo.one()
  end

  defp update_affected_orders(%{main_order: mo, sub_order_id: so}) do
    sub_order = Repo.get(Order, so)
    IO.inspect(sub_order)

    mo
    |> Order.update_changeset(%{merged_status: 1})
    |> Repo.update()

    sub_order
    |> Order.update_changeset(%{merged_status: 2})
    |> Repo.update()
  end

  def get_unique_dpt_stats() do
  end

  def get_department_stats(dpt_id) do
    subq =
      Order
      |> where([o], o.status != "voided")

    query =
      OrderDetail
      |> where([od], od.departement_id == ^dpt_id)
      |> join(:left, [od], orders in Order, on: orders.id == od.order_id)
      |> where([od, orders], orders.status != "voided")
      # |> where([od, orders] )
      |> join(:left, [od, orders], items in Item, on: items.id == od.item_id)
      # |> preload([od, orders, items])
      # |> group_by([od], od.id)
      |> select(
        [od, orders, items],
        [
          map(od, [:id, :sold_price, :sold_quantity]),
          # sum(od.sold_quantity)
          map(orders, [:code, :total, :inserted_at]),
          map(items, [:name])
        ]
      )

    format_dpt_with_query(query)
    # |> Enum.map(fn x ->
    #   case(Enum.fin())
    # end)
    # |> Enum.uniq_by(fn {a, _} -> a end)
  end

  def filter_by_date(date, dpt_id) do
    # {:ok, date} = NaiveDateTime.new(Date.from_iso8601!(date), ~T[00:00:00])
    IO.inspect(date)
    {:ok, date} = Date.from_iso8601(date)

    query =
      OrderDetail
      |> where(
        [od],
        fragment("?::date", od.inserted_at) == ^date and od.departement_id == ^dpt_id
      )
      |> join(:left, [od], orders in Order,
        on:
          orders.id == od.order_id and
            orders.status != "voided"
      )
      |> join(:left, [od, orders], items in Item, on: items.id == od.item_id)
      # |> preload([od, orders, items])
      # |> group_by([od], od.id)
      |> select(
        [od, orders, items],
        [
          map(od, [:id, :sold_price, :sold_quantity]),
          # sum(od.sold_quantity)
          map(orders, [:code, :total, :inserted_at]),
          map(items, [:name])
        ]
      )

    format_dpt_with_query(query)
  end

  def filter_by_date(:order, date, order_type) do
    # {:ok, date} = NaiveDateTime.new(Date.from_iso8601!(date), ~T[00:00:00])
    IO.inspect(date)
    {:ok, date} = Date.from_iso8601(date)

    query =
      Order
      |> where(
        [od],
        fragment("?::date", od.inserted_at) == ^date and od.status == ^order_type
      )

    Repo.all(query)
  end

  def format_dpt_with_query(query) do
    {:ok, dptArray} = Agent.start_link(fn -> [] end)

    Repo.all(query)
    |> Enum.map(fn [od, o, i] ->
      {
        i.name,
        %{
          "sold_price" => od.sold_price,
          "sold_quantity" => od.sold_quantity,
          "order_code" => o.code,
          "order_time" => o.inserted_at,
          "item_name" => i.name
        }
      }
    end)
    |> Enum.map(fn {_k, v} ->
      # if exit update otherwise insert
      # if Enum.member?(Agent.get(itemsArray, fn list -> list end), v) do
      my_list = Agent.get(dptArray, fn list -> list end)

      index =
        Enum.find_index(my_list, fn x ->
          x["item_name"] == v["item_name"] and x["sold_price"] == v["sold_price"]
        end)

      IO.puts("index is #{index}")

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
          Agent.update(dptArray, fn list -> List.replace_at(list, index, correct_map) end)
      end

      # else
      # end
    end)

    data = Agent.get(dptArray, fn list -> list end)
    Agent.stop(dptArray)
    data
  end

  def data() do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  def query(Order, args) do
    orders_query(args)
  end

  def query(queryable, _) do
    queryable
  end
end
