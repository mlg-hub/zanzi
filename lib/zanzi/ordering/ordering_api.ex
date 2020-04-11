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

  def get_order!(id), do: Repo.get!(Order, id)

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

  def create_empty_split(attrs \\ %{}) do
    split_changeset =
      %Order{}
      |> Order.create_split_changeset(attrs)

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
        {:error, "your changeset is invalid"}
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
      |> Order.update_split_changeset(%{total: total, filled: 2, splitted_from: order_id})
      |> Repo.update()

    with {:ok, order} <- split_changeset do
      Enum.each(attrs.items, fn x ->
        changeset =
          %OrderDetail{}
          |> OrderDetail.changeset(Map.put(x, :order_id, order.id))

        case Repo.insert!(changeset) do
          %OrderDetail{} ->
            %{status: "success"}

          _ ->
            %{}
        end
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
                  query

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

  def create_payment(attrs \\ %{}) do
    case Repo.get(Order, Map.get(attrs, :order_id)) do
      %Order{} = order ->
        attrs = Map.put(attrs, :order_total, order.total)

        payments =
          %OrderPayment{}
          |> OrderPayment.changeset(attrs)
          |> Repo.insert!()

        case payments do
          %OrderPayment{} = payments ->
            with %{order_id: order_id} <- attrs do
              case Repo.get(Order, order_id) do
                %Order{} = order ->
                  case update_order(order, %{status: "paid"}) do
                    nil -> {:error, "error occured"}
                    _ -> {:ok, %{payment: "success"}}
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

  def update_order(%Order{} = order, attrs) do
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
        on: is_nil(orders.total) and not is_nil(orders.table_id)
      )
      |> join(:left, [u, orders], table in Table, on: orders.table_id == table.id)
      |> order_by([u, orders, table], asc: orders.ordered_at)
      |> preload([u, orders, table], orders: {orders, table: table})

    Repo.all(query)
  end

  def get_all_orders_from_waiter(username) do
    user = Repo.get_by(User, %{username: username})

    query =
      User
      |> where([u], u.id == ^user.id)
      |> join(:left, [u], orders in assoc(u, :orders),
        on:
          (orders.merged_status == 0 or
             orders.merged_status == 1) and
            (orders.filled == 1 and not is_nil(orders.total))
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

  def get_cleared_bill(user_id) do
    query =
      OrderPayment
      |> where([p], p.user_id == ^user_id)
      |> join(:left, [p], o in assoc(p, :order), on: o.status == "paid")
      # |> join(:left, [p, o], d in assoc(o, :order_details))
      |> preload([p, o], order: o)

    Repo.all(query)
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

  def get_pending_orders do
    query = from u in Order, where: u.status == "created"
    Repo.all(query)
  end

  def get_incomplete_orders do
    query = from u in Order, where: u.status == "incomplete"
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
