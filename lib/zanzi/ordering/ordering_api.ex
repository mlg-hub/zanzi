defmodule Zanzibloc.Ordering.OrderingApi do
  @moduledoc """
  The Ordering context.
  """

  import Ecto.Query, warn: false
  alias Zanzi.Repo
  alias Timex
  require Logger

  alias Zanzibloc.Ordering.{
    Order,
    OrderDetail,
    OrderPayment,
    OrderOwner,
    TableOrders,
    Table,
    OrderSplit,
    OrderMerged,
    VoidReason,
    CashierShift
  }

  alias Zanzibloc.Menu.Item
  alias Zanzibloc.Account.User

  def list_orders do
    Repo.all(Order)
  end

  def get_all_tables do
    Repo.all(Table)
  end

  def get_all_request_void do
    query =
      Order
      |> where([o], o.void_request == 1)
      |> join(:inner, [o], owner in assoc(o, :owner))
      |> preload([o, ow], owner: ow)

    Repo.all(query)
  end

  def get_shift_state(%{user_id: user_id}) do
    shift = Repo.one(from c in CashierShift, where: c.shift_status == 1 and c.user_id == ^user_id)

    cond do
      shift == nil -> %{status: "false"}
      true -> %{status: "true"}
    end
  end

  def void_order(order_id, reason) do
    order = Repo.get(Order, order_id)

    case order do
      %Order{} = result_order ->
        void_my_order(result_order, reason)

      _ ->
        %{error: "order not found"}
    end
  end

  def request_void(order_id) do
    order = Repo.get(Order, order_id)

    case order do
      %Order{} = result_order ->
        send_void_request(result_order)

      _ ->
        %{error: "order not found"}
    end
  end

  defp send_void_request(order) do
    changeset = order |> Order.update_changeset(%{void_request: 1})

    case Repo.update(changeset) do
      {:ok, _} -> %{status: "success"}
      _ -> %{error: "cant send request the order"}
    end
  end

  defp void_my_order(order, reason) do
    # TODO: set the voiding reason
    changeset = order |> Order.update_changeset(%{status: "voided"})

    case Repo.update(changeset) do
      {:ok, _} ->
        void_changeset =
          %VoidReason{} |> VoidReason.changeset(%{order_id: order.id, void_reason: reason})

        with %VoidReason{} <- Repo.insert!(void_changeset) do
          changeset = order |> Order.update_changeset(%{void_request: 0})
          Repo.update(changeset)
          %{status: "success"}
        else
          _ -> %{error: "cant void the order"}
        end

      _ ->
        %{error: "cant void the order"}
    end
  end

  def get_order!(id), do: Repo.get!(Order, id)

  def get_items(route) do
    case route do
      :bar ->
        query = from(i in Item, where: i.departement_id == 1)
        Repo.all(query)

      :kitchen ->
        query = from(i in Item, where: i.departement_id == 2)
        Repo.all(query)

      :coffee ->
        query = from(i in Item, where: i.departement_id == 3)
        Repo.all(query)

      :restaurant ->
        query = from(i in Item, where: i.departement_id == 5)
        Repo.all(query)

      :mini_bar ->
        query = from(i in Item, where: i.departement_id == 6)
        Repo.all(query)

      _ ->
        []
    end
  end

  def send_transfer_request(%{order: order, transfer: transfer_to}) do
    order_to_transfer = Repo.get_by!(OrderOwner, %{order_id: order})

    with %OrderOwner{} = order <- order_to_transfer do
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

  def get_one_shift(shift_id) do
    Repo.one(from c in CashierShift, where: c.id == ^shift_id)
  end

  def get_all_cashier_shifts do
    # Repo.preload(CashierShift, :cashier)
    query =
      CashierShift
      |> where([c], not is_nil(c.shift_end))
      |> join(:inner, [c], d in assoc(c, :user), on: c.user_id == d.id)
      |> order_by([c], desc: c.inserted_at)
      |> preload([c, d], user: d)

    Repo.all(query)
  end

  def create_new_shift(attrs) do
    shift =
      Repo.one(
        from c in CashierShift, where: c.shift_status == 1 and c.user_id == ^attrs.cashier_id
      )

    if shift == nil do
      shift_changeset =
        %CashierShift{}
        |> CashierShift.create_new_shift(%{
          user_id: attrs.cashier_id,
          shift_start: DateTime.utc_now()
        })

      bill_time = NaiveDateTime.local_now()

      case(PosCalculation.see_bill(bill_time)) do
        :gt ->
          case Repo.insert!(shift_changeset) do
            %CashierShift{} = shift ->
              Repo.all(from o in Order, where: o.status == "created")
              |> Enum.each(fn current_order ->
                if current_order.cashier_shifts_id == shift.id - 1 do
                  Order.update_order_current_shift(current_order, %{cashier_shifts_id: shift.id})
                  |> Repo.update()
                end
              end)

              {:ok}

            _ ->
              {:error}
          end

        :lt ->
          nil

        _ ->
          nil
      end
    end
  end

  def close_shift(cashier_id) do
    r = get_sales_stats_print(cashier_id)

    shift_query =
      Repo.one(from s in CashierShift, where: s.shift_status == 1 and s.user_id == ^cashier_id)

    # getting all pending order for this shift
    if shift_query do
      shift_changeset =
        shift_query
        |> CashierShift.create_closing_chgset(%{
          shift_status: 0,
          shift_end: Timex.local()
        })

      case Repo.update(shift_changeset) do
        {:ok, _} -> {:ok, r}
        _ -> {:error, %{error: "can't close the shift"}}
      end
    end

    {:ok, r}
  end

  def create_empty_split(attrs) do
    active_shift = Repo.all(from s in CashierShift, where: s.shift_status == 1)

    cond do
      Enum.count(active_shift) == 0 ->
        {:error, "cant open!"}

      true ->
        query =
          OrderOwner
          |> where([o], o.current_owner == ^Map.get(attrs, :user_id))
          |> join(:inner, [o], ox in assoc(o, :order),
            on: ox.total == 0
          )

        re = Repo.all(query)

        Enum.each(re, fn o -> Repo.delete(o) end)

        case Enum.count([]) do
          0 ->
            attrs = Map.put(attrs, :filled, 0)
            # attrs = Map.put(attrs, :cashier_shifts_id, active_shift.id)

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
                %{message: "your changeset is invalid"}
            end

          _ ->
            {:error, "Could not split"}
        end
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
        %OrderDetail{}
        |> OrderDetail.changeset(Map.put(x, :order_id, order.id))
        |> Repo.insert!()
      end)

      mutate_order(order_id, attrs.items, total)

      %{status: "success"}
    end
  end

  defp check_if_staff(attrs) do
    order_category = Map.get(attrs, :order_category)

    case order_category do
      1 ->
        attrs

      2 ->
        Map.put(attrs, :staff_discount, 40)
    end
  end

  def create_order(attrs \\ %{}) do
    #  item = %{id, quantity}
    # get current shift
    IO.inspect(attrs)

    case(PosCalculation.get_server_status(NaiveDateTime.local_now())) do
      :gt ->
        current_shift = Repo.all(from s in CashierShift, where: s.shift_status == 1)
        IO.puts("is greater than")

        cond do
          Enum.count(current_shift) > 0 ->
            attrs = Map.update(attrs, :items, [], &build_items/1)

            total =
              Enum.reduce(
                Map.get(attrs, :items),
                0,
                fn %{sold_quantity: qty, sold_price: p}, acc ->
                  qty * p + acc
                end
              )

            attrs = Map.put(attrs, :total, total)

            attrs = check_if_staff(attrs)

            save_changeset =
              %Order{}
              |> Order.changeset(attrs)

            case Repo.insert!(save_changeset) do
              %Order{} = order ->
                owner_attrs = %{current_owner: Map.get(attrs, :user_id), order_id: order.id}
                owner_changeset = %OrderOwner{} |> OrderOwner.changeset(owner_attrs)

                with %OrderOwner{} <- Repo.insert!(owner_changeset) do
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
                            |> join(:left, [detail, order], item in ^Item,
                              on: item.id == detail.item_id
                            )
                            |> join(:left, [detail, order, item], owner in assoc(order, :owner))
                            # |> select([detail, _, _, _], %{detail_info: detail.id})
                            |> preload([detail, order, item, owner],
                              order: {order, owner: owner},
                              item: item
                            )
                            |> Repo.one()

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

          true ->
            {:error, "something went wrong"}
        end

      :lt ->
        require Logger
        Logger.warn("there is an error here!!!!!")
        nil

      _ ->
        nil
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

                  %{query: query, update: x}

                _ ->
                  %{}
              end
          end
        end)

      {:ok, %{order: main_returned_order, details: saved_bon_commande}}
    end
  end

  def create_payment(attrs \\ %{}) do
    shift_selected =
      Repo.one(from c in CashierShift, where: c.shift_status == 1 and c.user_id == ^attrs.user_id)

    if shift_selected != nil do
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
            %OrderPayment{} ->
              with %{order_id: order_id} <- attrs do
                case Repo.get(Order, order_id) do
                  %Order{} = order ->
                    cond do
                      total_paid < total_amount ->
                        case update_order_clearance(order, %{
                               status: "incomplete",
                               cashier_shifts_id: shift_selected.id
                             }) do
                          nil -> {:error, "error occured"}
                          _ -> {:ok, %{payment: "success"}}
                        end

                      total_paid == total_amount ->
                        case update_order_clearance(order, %{
                               status: "paid",
                               cashier_shifts_id: shift_selected.id
                             }) do
                          nil -> {:error, "error occured"}
                          _ -> {:ok, %{payment: "success"}}
                        end

                      total_paid > total_amount ->
                        case update_order_clearance(order, %{
                               status: "paid",
                               cashier_shifts_id: shift_selected.id
                             }) do
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
    IO.puts("on updating order ....")
    IO.inspect(attrs)

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
      |> join(:inner, [u], orders in assoc(u, :orders),
        on:
          orders.filled == 0 and not is_nil(orders.table_id) and
            fragment("?::date", orders.inserted_at) == ^Date.utc_today()
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


    r = Repo.one(query)
    IO.inspect(r)
    r
  end

  def get_current_shift_cleared(shift_id, user_id) do
    query =
      Order
      |> where([o], o.status == "paid" and o.cashier_shifts_id == ^shift_id)
      |> join(:inner, [o], p in assoc(o, :payments), on: p.user_id == ^user_id)
      |> order_by([o, p], desc: p.inserted_at)
      # |> join(:left, [p, o], d in assoc(o, :order_details))
      |> preload([o, p], payments: p)

    Repo.all(query)
  end

  def get_cleared_bill(date, user_id) do
    current_shift = Repo.one(from s in CashierShift, where: s.shift_status == 1 and s.user_id == ^user_id)

    cond do
      date == "0" && current_shift != nil ->
        get_current_shift_cleared(current_shift.id, user_id)

      true ->
        {:ok, date} = Date.from_iso8601(date)

        query =
          Order
          |> where([o], o.status == "paid")
          |> join(:inner, [o], p in assoc(o, :payments),
            on: p.user_id == ^user_id and fragment("?::date", p.inserted_at) == ^date
          )
          |> order_by([o, p], desc: p.inserted_at)
          # |> join(:left, [p, o], d in assoc(o, :order_details))
          |> preload([o, p], payments: p)

        Repo.all(query)
    end
  end

  def get_bill(filter) do
    case filter do
      :pending ->
        query = Order |> limit(200) |> where([o], o.status == "created") |> reverse_order()

        Repo.all(query, preload: :owner)

      :voided ->
        query =
          Order
          |> limit(200)
          |> where([o], o.status == "voided")
          |> join(:inner, [o], v in assoc(o, :void_reason))
          |> preload([o, v], void_reason: v)
          |> reverse_order()

        Repo.all(query)

      :cleared ->
        query = Order |> limit(200) |> where([o], o.status == "paid") |> reverse_order()

        Repo.all(query, preload: :owner)

      :unpaid ->
        query =
          Order
          |> limit(200)
          |> where([o], o.status == "incomplete")
          |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == "unpaid")
          |> preload([o, p], payments: p)
          |> reverse_order()

        Repo.all(query, preload: :owner)

      :complementary ->
        query =
          Order
          |> limit(200)
          |> where([o], o.status == "incomplete")
          |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == "complementary")
          |> preload([o, p], payments: p)
          |> reverse_order()

        Repo.all(query, preload: :owner)

      :remain ->
        query =
          Order
          |> limit(200)
          |> where([o], o.status == "incomplete")
          |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == "sales")
          |> preload([o, p], payments: p)
          |> reverse_order()

        Repo.all(query, preload: :owner)

      _ ->
        []
    end
  end

  def get_pending_bill() do
    query = from(o in Order, where: o.status == "created")
    Repo.all(query)
  end

  def get_order_details(order_id) do
    case Repo.get(Order, order_id) do
      %Order{} = order ->
        case order.merged_status do
          0 -> format_order_details(order)
          1 -> display_merged_bill(order.id)
        end

      _ ->
        {:error, "order does not exist"}
    end
  end

  defp format_order_details(%Order{} = order) do
    query =
      Order
      |> where([o], o.id == ^order.id)
      |> join(:inner, [o], details in assoc(o, :order_details), on: details.sold_quantity > 0)
      |> join(:inner, [o, d], item in assoc(d, :item))
      |> join(:inner, [o, d, i], payments in assoc(o, :payments))
      |> select([o, d, i, p], [
        map(o, [:id, :code, :total]),
        map(d, [:sold_quantity, :sold_price]),
        map(i, [:name]),
        map(p, [:order_paid])
      ])
      |> Repo.all()
      |> Enum.map(fn [map1, map2, map3, map4] ->
        t1 = Map.merge(map1, map2)
        tfinal = Map.merge(t1, map3)

        case map4 do
          nil -> Map.put(tfinal, :paid, false)
          _ -> Map.merge(Map.put(tfinal, :paid, true), map4)
        end
      end)
  end

  def get_sales_stats_current(user_id) do
    shift_selected =
      Repo.one(from c in CashierShift, where: c.shift_status == 1 and c.user_id == ^user_id)

    if shift_selected != nil do
      query =
        Order
        |> where(
          [o],
          o.status == "paid" and
            o.cashier_shifts_id == ^shift_selected.id
        )
        |> join(:inner, [o], od in assoc(o, :order_details))
        |> join(:inner, [o, od], dpt in assoc(od, :departement))
        |> select([o, od, dpt], [
          map(od, [:item_id, :sold_price, :sold_quantity]),
          map(dpt, [:name])
        ])

      all_shifts =
        Repo.all(
          from c in CashierShift,
            where: c.user_id == ^user_id and c.shift_status == 0 and not is_nil(c.shift_end)
        )

      all_sales = Repo.all(query)
      {:ok, kitchen} = Agent.start_link(fn -> 0 end)
      {:ok, bar} = Agent.start_link(fn -> 0 end)
      {:ok, mini_bar} = Agent.start_link(fn -> 0 end)
      {:ok, restaurant} = Agent.start_link(fn -> 0 end)

      Enum.each(all_sales, fn [%{sold_price: price, sold_quantity: qty}, %{name: dpt}] ->
        case String.downcase(dpt) do
          "main bar" ->
            Agent.update(bar, Kernel, :+, [price * qty])

          "kitchen" ->
            Agent.update(kitchen, Kernel, :+, [price * qty])

          "mini bar" ->
            Agent.update(mini_bar, Kernel, :+, [price * qty])

          "restaurant" ->
            Agent.update(restaurant, Kernel, :+, [price * qty])

          _ ->
            0
        end
      end)

      kitchenT = Agent.get(kitchen, fn tot -> tot end)
      barT = Agent.get(bar, fn tot -> tot end)
      restaurantT = Agent.get(restaurant, fn tot -> tot end)
      mini_barT = Agent.get(mini_bar, fn tot -> tot end)

      r = %{
        kitchen: Agent.get(kitchen, fn tot -> tot end),
        bar: Agent.get(bar, fn tot -> tot end),
        restaurant: Agent.get(restaurant, fn tot -> tot end),
        mini_bar: Agent.get(mini_bar, fn tot -> tot end),
        total: kitchenT + mini_barT + restaurantT + barT,
        shifts: all_shifts
      }

      Agent.stop(kitchen)
      Agent.stop(bar)
      Agent.stop(mini_bar)
      Agent.stop(restaurant)
      r
    end
  end

  def get_sales_stats_print(user_id) do
    # get the selected shift
    shift_selected =
      Repo.one(
        from c in CashierShift,
          where: c.shift_status == 1 and c.user_id == ^user_id,
          preload: :user
      )

    if shift_selected != nil do
      result =
        Enum.map(["paid", "complementary", "unpaid"], fn element ->
          query =
            case element do
              "paid" ->
                Order
                |> where(
                  [o],
                  o.status == ^element and
                    o.cashier_shifts_id == ^shift_selected.id
                )
                |> join(:inner, [o], od in assoc(o, :order_details))
                |> join(:inner, [o, od], dpt in assoc(od, :departement))
                |> select([o, od, dpt], [
                  map(od, [:item_id, :sold_price, :sold_quantity]),
                  # map(p, [:order_id, :order_paid, :order_total]),
                  map(dpt, [:name])
                ])

              _ ->
                Order
                |> where(
                  [o],
                  o.status == "incomplete" and
                    o.cashier_shifts_id == ^shift_selected.id
                )
                |> join(:inner, [o], p in assoc(o, :payments),
                  on: p.order_type == ^element and p.user_id == ^user_id
                )
                |> join(:inner, [o, p], od in assoc(o, :order_details))
                |> join(:inner, [o, p, od], dpt in assoc(od, :departement))
                |> select([o, p, od, dpt], [
                  map(od, [:item_id, :sold_price, :sold_quantity]),
                  map(dpt, [:name])
                ])
            end

          all_sales = Repo.all(query)
          {:ok, kitchen} = Agent.start_link(fn -> 0 end)
          {:ok, bar} = Agent.start_link(fn -> 0 end)
          {:ok, mini_bar} = Agent.start_link(fn -> 0 end)
          {:ok, restaurant} = Agent.start_link(fn -> 0 end)

          Enum.each(all_sales, fn [%{sold_price: price, sold_quantity: qty}, %{name: dpt}] ->
            case String.downcase(dpt) do
              "main bar" ->
                Agent.update(bar, Kernel, :+, [price * qty])

              "kitchen" ->
                Agent.update(kitchen, Kernel, :+, [price * qty])

              "mini bar" ->
                Agent.update(mini_bar, Kernel, :+, [price * qty])

              "restaurant" ->
                Agent.update(restaurant, Kernel, :+, [price * qty])

              _ ->
                0
            end
          end)

          kitchenT = Agent.get(kitchen, fn tot -> tot end)
          barT = Agent.get(bar, fn tot -> tot end)
          restaurantT = Agent.get(restaurant, fn tot -> tot end)
          mini_barT = Agent.get(mini_bar, fn tot -> tot end)

          r = %{
            category: element,
            stats: %{
              kitchen: Agent.get(kitchen, fn tot -> tot end),
              bar: Agent.get(bar, fn tot -> tot end),
              restaurant: Agent.get(restaurant, fn tot -> tot end),
              mini_bar: Agent.get(mini_bar, fn tot -> tot end),
              total: kitchenT + mini_barT + restaurantT + barT
            }
          }

          Agent.stop(kitchen)
          Agent.stop(bar)
          Agent.stop(mini_bar)
          Agent.stop(restaurant)
          r
        end)

      %{result: result, shift_infos: shift_selected}
    end
  end

  def get_sales_stats(shift_id, user_id) do
    # get the selected shift
    shift_selected = Repo.one(from c in CashierShift, where: c.id == ^shift_id)

    if shift_selected != nil do
      query =
        Order
        |> where(
          [o],
          o.status == "paid" and
            o.cashier_shifts_id == ^shift_selected.id
        )
        |> join(:inner, [o], od in assoc(o, :order_details))
        |> join(:inner, [o, od], dpt in assoc(od, :departement))
        |> select([o, od, dpt], [
          map(od, [:item_id, :sold_price, :sold_quantity]),
          map(dpt, [:name])
        ])

      all_shifts =
        Repo.all(
          from c in CashierShift,
            where: c.user_id == ^user_id and c.shift_status == 0 and not is_nil(c.shift_end)
        )

      all_sales = Repo.all(query)
      {:ok, kitchen} = Agent.start_link(fn -> 0 end)
      {:ok, bar} = Agent.start_link(fn -> 0 end)
      {:ok, mini_bar} = Agent.start_link(fn -> 0 end)
      {:ok, restaurant} = Agent.start_link(fn -> 0 end)

      Enum.each(all_sales, fn [%{sold_price: price, sold_quantity: qty}, %{name: dpt}] ->
        case String.downcase(dpt) do
          "main bar" ->
            Agent.update(bar, Kernel, :+, [price * qty])

          "kitchen" ->
            Agent.update(kitchen, Kernel, :+, [price * qty])

          "mini bar" ->
            Agent.update(mini_bar, Kernel, :+, [price * qty])

          "restaurant" ->
            Agent.update(restaurant, Kernel, :+, [price * qty])

          _ ->
            0
        end
      end)

      kitchenT = Agent.get(kitchen, fn tot -> tot end)
      barT = Agent.get(bar, fn tot -> tot end)
      restaurantT = Agent.get(restaurant, fn tot -> tot end)
      mini_barT = Agent.get(mini_bar, fn tot -> tot end)

      r = %{
        kitchen: Agent.get(kitchen, fn tot -> tot end),
        bar: Agent.get(bar, fn tot -> tot end),
        restaurant: Agent.get(restaurant, fn tot -> tot end),
        mini_bar: Agent.get(mini_bar, fn tot -> tot end),
        total: kitchenT + mini_barT + restaurantT + barT,
        shifts: all_shifts
      }

      Agent.stop(kitchen)
      Agent.stop(bar)
      Agent.stop(mini_bar)
      Agent.stop(restaurant)
      r
    end
  end

  def get_pending_orders(date,user_id) do
    {:ok, date} = Date.from_iso8601(date)

    query =
      Order
      |> where([o], o.status == "created" and fragment("?::date", o.inserted_at) == ^date)
      |> preload([:owner, :table])

    o = Repo.all(query)
    IO.puts("orders list #{inspect(o)}")
    o
  end

  def get_current_shift_uc(shift_id, type) do
    query =
      Order
      |> where([o], o.status == "incomplete" and o.cashier_shifts_id == ^shift_id)
      |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == ^type)
      |> preload([:owner, :table])

    Repo.all(query)
  end

  # @spec get_incomplete_orders :: any
  def get_incomplete_orders(:unpaid, date,user_id) do
    require Logger
    Logger.info(date)
    current_shift = Repo.one(from s in CashierShift, where: s.shift_status == 1 and s.user_id == ^user_id)
    Logger.info(current_shift.id)

    cond do
      date == "0" && current_shift != nil ->
        get_current_shift_uc(current_shift.id, "unpaid")

      true ->
        {:ok, date} = Date.from_iso8601(date)

        query =
          Order
          |> where([o], o.status == "incomplete")
          |> join(:inner, [o], p in assoc(o, :payments),
            on: fragment("?::date", p.inserted_at) == ^date and p.order_type == "unpaid"
          )
          |> preload([:owner, :table])

        Repo.all(query)
    end
  end

  def get_incomplete_orders(:complementary, date,user_id) do
    current_shift = Repo.one(from s in CashierShift, where: s.shift_status == 1 and s.user_id == ^user_id)

    cond do
      date == "0" && current_shift != nil ->
        get_current_shift_uc(current_shift.id, "complementary")

      true ->
        {:ok, date} = Date.from_iso8601(date)

        query =
          Order
          |> where([o], o.status == "incomplete")
          |> join(:inner, [o], p in assoc(o, :payments),
            on: fragment("?::date", o.updated_at) == ^date and p.order_type == "complementary"
          )
          |> preload([:owner, :table])

        Repo.all(query)
    end
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

    mo
    |> Order.update_changeset(%{merged_status: 1})
    |> Repo.update()

    sub_order
    |> Order.update_changeset(%{merged_status: 2})
    |> Repo.update()
  end

  def get_unique_dpt_stats() do
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
          map(p, [:order_paid]),
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

  defp process_query(:shift, shift, target, sous_target, dpt_id) do
    query =
      Order
      |> where(
        [o],
        o.status == ^target and o.cashier_shifts_id == ^shift
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

  defp process_query(:shift, shift, target, dpt_id) do
    query =
      Order
      |> where(
        [o],
        o.status == ^target and o.cashier_shifts_id == ^shift
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
        format_dpt_with_query(:staff, query)

      "complementary" ->
        query = process_query("incomplete", "complementary", dpt_id)
        format_dpt_with_query(:staff, query)

      _ ->
        []
    end
  end

  defp get_department_stats_by_shift(shift, cat, dpt_id) do
    case cat do
      "paid" ->
        query = process_query(:shift, shift, "paid", dpt_id)
        format_dpt_with_query(query)

      "pending" ->
        query = process_query(:shift, shift, "created", dpt_id)
        format_dpt_with_query(query)

      "voided" ->
        query = process_query(:shift, shift, "voided", dpt_id)
        format_dpt_with_query(query)

      "unpaid" ->
        query = process_query(:shift, shift, "incomplete", "unpaid", dpt_id)
        format_dpt_with_query(query)

      "complementary" ->
        query = process_query(:shift, shift, "incomplete", "complementary", dpt_id)
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

    pendingT = Task.await(pending, :infinity)
    paidT = Task.await(paid, :infinity)
    complementaryT = Task.await(compl, :infinity)
    unpaidT = Task.await(unpaid, :infinity)
    voidedT = Task.await(voided, :infinity)

    %{
      "pending" => pendingT,
      "paid" => paidT,
      "complementary" => complementaryT,
      "unpaid" => unpaidT,
      "voided" => voidedT
    }
  end

  def filter_by_shift(shift_id, dpt_id) do
    {:ok, pending_pid} = Task.Supervisor.start_link()
    {:ok, paid_pid} = Task.Supervisor.start_link()
    {:ok, voided_pid} = Task.Supervisor.start_link()
    {:ok, unpaid_pid} = Task.Supervisor.start_link()
    {:ok, compl_pid} = Task.Supervisor.start_link()

    pending =
      Task.Supervisor.async(pending_pid, fn ->
        get_department_stats_by_shift(shift_id, "pending", dpt_id)
      end)

    paid =
      Task.Supervisor.async(paid_pid, fn ->
        get_department_stats_by_shift(shift_id, "paid", dpt_id)
      end)

    unpaid =
      Task.Supervisor.async(unpaid_pid, fn ->
        get_department_stats_by_shift(shift_id, "unpaid", dpt_id)
      end)

    compl =
      Task.Supervisor.async(compl_pid, fn ->
        get_department_stats_by_shift(shift_id, "complementary", dpt_id)
      end)

    voided =
      Task.Supervisor.async(voided_pid, fn ->
        get_department_stats_by_shift(shift_id, "voided", dpt_id)
      end)

    pendingT = Task.await(pending, :infinity)
    paidT = Task.await(paid, :infinity)
    complementaryT = Task.await(compl, :infinity)
    unpaidT = Task.await(unpaid, :infinity)
    voidedT = Task.await(voided, :infinity)

    %{
      "pending" => pendingT,
      "paid" => paidT,
      "complementary" => complementaryT,
      "unpaid" => unpaidT,
      "voided" => voidedT
    }
  end

  def filter_by_date(date, dpt_id) do
    # {:ok, date} = NaiveDateTime.new(Date.from_iso8601!(date), ~T[00:00:00])

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

    pendingT = Task.await(pending, :infinity)
    paidT = Task.await(paid, :infinity)
    complementaryT = Task.await(compl, :infinity)
    unpaidT = Task.await(unpaid, :infinity)
    voidedT = Task.await(voided, :infinity)

    %{
      "pending" => pendingT,
      "paid" => paidT,
      "complementary" => complementaryT,
      "unpaid" => unpaidT,
      "voided" => voidedT
    }
  end

  def filter_by_shift(:order_shift, shift_id, order_type) do
    case order_type do
      "incomplete" ->
        query =
          Order
          |> where(
            [o],
            o.cashier_shifts_id == ^shift_id and o.status == ^order_type and
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
            od.status == ^order_type and od.cashier_shifts_id == ^shift_id
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
            od.cashier_shifts_id == ^shift_id and od.status == ^order_type and
              od.total != 0
          )

        Repo.all(query)

      "unpaid" ->
        query =
          Order
          |> where([o], o.cashier_shifts_id == ^shift_id and o.status == "incomplete")
          |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == "unpaid")
          |> preload([o, p], payments: p)

        Repo.all(query, preload: :owner)

      "complementary" ->
        query =
          Order
          |> where([o], o.cashier_shifts_id == ^shift_id and o.status == "incomplete")
          |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == "complementary")
          |> preload([o, p], payments: p)

        Repo.all(query, preload: :owner)

      "remain" ->
        query =
          Order
          |> where([o], o.cashier_shifts_id == ^shift_id and o.status == "incomplete")
          |> join(:left, [o], p in assoc(o, :payments))
          |> preload([o, p], payments: p)

        Repo.all(query, preload: :owner)

      _ ->
        []
    end
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
          |> join(:inner, [o], p in assoc(o, :payments), on: p.order_type == "sales")
          |> preload([o, p], payments: p)

        Repo.all(query, preload: :owner)

      _ ->
        []
    end
  end

  def format_dpt_with_query(:staff, query) do
    {:ok, dptArray} = Agent.start_link(fn -> [] end)
    {:ok, count} = Agent.start_link(fn -> 1 end)

    Repo.all(query)
    |> Enum.map(fn [od, p, o, i] = elts ->
      if o != nil and elts != nil do
        {
          i.name,
          %{
            "sold_price" => od.sold_price,
            "sold_quantity" => od.sold_quantity,
            "total_paid" => p.order_paid,
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
