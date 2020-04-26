defmodule ZanziWeb.Resolvers.OrderingResolvers do
  alias Zanzibloc.Ordering.{OrderingApi, OrderDetail, Order}
  alias Zanzibloc.Account.{User}
  alias Zanzibloc.Menu.Item
  alias Zanzibloc.Cache.{ToprintBar, ToKitchen, ToprintMiniBar, ToprintRestaurant}
  require Logger

  def prepare_order(_, %{id: id}, _) do
    order = OrderingApi.get_order!(id)

    with {:ok, order} <- OrderingApi.update_order(order, %{status: "prepare"}) do
      {:ok, %{order: order}}
    end
  end

  def void_order(_, %{order_id: order_id}, _) do
    {:ok, OrderingApi.void_order(order_id)}
  end

  def get_all_tables(_, _, _) do
    {:ok, OrderingApi.get_all_tables()}
  end

  def send_transfer_request(_, %{order_id: order, receiver_id: receiver}, _) do
    case OrderingApi.send_transfer_request(%{order: order, transfer: receiver}) do
      {:ok, _} -> {:ok, %{status: "request sent with success"}}
      _ -> {:error, "You can not send request"}
    end
  end

  def accept_transfer_request(_, %{order_id: order}, _) do
    case OrderingApi.accept_transfer_request(%{order: order}) do
      {:ok, _} -> {:ok, %{status: "request accepted"}}
      _ -> {:error, "You can not send request"}
    end
  end

  def reject_transfer_request(_, %{order_id: order}, _) do
    case OrderingApi.accept_transfer_request(%{order: order}) do
      {:ok, _} -> {:ok, %{status: "request rejected"}}
      _ -> {:error, "You can not send request"}
    end
  end

  def pay_order(_, args, %{context: context}) do
    case context[:current_user] do
      %User{} = user ->
        IO.inspect(user)
        args = Map.put(args, :user_id, user.id)

        with {:ok, _} <- OrderingApi.create_payment(args) do
          {:ok, %{status: "success"}}
        end

      _ ->
        {:error, "Error auth"}
    end
  end

  defp split_to_departement(bon_de_commande) do
    {:ok, kitchen} = Agent.start_link(fn -> [] end)
    {:ok, bar} = Agent.start_link(fn -> [] end)
    {:ok, restaurant} = Agent.start_link(fn -> [] end)
    {:ok, minibar} = Agent.start_link(fn -> [] end)
    IO.inspect(bon_de_commande)

    Enum.each(
      bon_de_commande,
      fn %{query: details, update: update} ->
        %OrderDetail{departement_id: dpt} = details

        case update do
          nil ->
            case dpt do
              2 ->
                kitchen_map = transform_order_details(details, "Kitchen")
                Agent.update(kitchen, fn list -> [kitchen_map | list] end)

              1 ->
                bar_map = transform_order_details(details, "Bar")
                Agent.update(bar, fn list -> [bar_map | list] end)

              4 ->
                restaurant_map = transform_order_details(details, "Restaurant")
                Agent.update(restaurant, fn list -> [restaurant_map | list] end)

              5 ->
                minibar_map = transform_order_details(details, "Mini Bar")
                Agent.update(minibar, fn list -> [minibar_map | list] end)

              _ ->
                Logger.error("did not match any departement")
                # IO.inspect(dpt)
            end

          _ ->
            case dpt do
              2 ->
                kitchen_map = transform_order_details_update(details, update, "Kitchen")
                Agent.update(kitchen, fn list -> [kitchen_map | list] end)

              1 ->
                bar_map = transform_order_details_update(details, update, "Bar")
                Agent.update(bar, fn list -> [bar_map | list] end)

              4 ->
                restaurant_map = transform_order_details_update(details, update, "Restaurant")
                Agent.update(restaurant, fn list -> [restaurant_map | list] end)

              5 ->
                minibar_map = transform_order_details_update(details, update, "Mini Bar")
                Agent.update(minibar, fn list -> [minibar_map | list] end)

              _ ->
                Logger.error("did not match any departement")
                # IO.inspect(dpt)
            end
        end
      end
    )

    toKitchen = Agent.get(kitchen, fn list -> list end)
    toBar = Agent.get(bar, fn list -> list end)
    toRestaurant = Agent.get(restaurant, fn list -> list end)
    toMinibar = Agent.get(minibar, fn list -> list end)

    Logger.info("new structure baby")
    IO.inspect(toBar)

    if Enum.count(toKitchen) > 0 do
      ToKitchen.add_new(toKitchen)
    end

    if Enum.count(toRestaurant) > 0 do
      ToprintRestaurant.add_new(toRestaurant)
    end

    if Enum.count(toMinibar) > 0 do
      ToprintMiniBar.add_new(toRestaurant)
    end

    if Enum.count(toBar) > 0 do
      ToprintBar.add_new(toBar)
    end

    Agent.stop(kitchen)
    Agent.stop(bar)
    Agent.stop(restaurant)
    Agent.stop(minibar)
  end

  def set_printed(_, %{order_id: id}, _) do
    with {:ok, _} <- OrderingApi.set_printed(id) do
      {:ok, %{status: "success"}}
    else
      _ -> {:error, %{message: "not set printed_status"}}
    end
  end

  def place_order(_, %{input: place_order_input, table: table}, %{context: context}) do
    place_order_input =
      case context[:current_user] do
        %User{} = user ->
          Map.put(place_order_input, :user_id, user.id)

        _ ->
          place_order_input
      end

    place_order_input = Map.put(place_order_input, :table_id, table)

    with {:ok, %{order: _order, details: saved_bon_commande}} <-
           OrderingApi.create_order(place_order_input) do
      split_to_departement(saved_bon_commande)
      {:ok, %{status: "success"}}
    else
      _ ->
        Logger.error("kulalala")
        {:error, "Error occured"}
    end
  end

  def update_place_order(_, %{input: place_order_input, order_id: order_id}, %{context: context}) do
    place_order_input =
      case context[:current_user] do
        %User{} = user ->
          Map.put(place_order_input, :user_id, user.id)

        _ ->
          place_order_input
      end

    with {:ok, %{order: _order, details: saved_bon_commande}} <-
           OrderingApi.update_order(order_id, place_order_input) do
      split_to_departement(saved_bon_commande)
      {:ok, %{status: "success"}}
    else
      _ ->
        Logger.error("kulalala")
        {:error, "Error occured"}
    end
  end

  def merge_bills(_, %{main_order_id: mo, sub_order_ids: soi}, %{context: context}) do
    {:ok,
     OrderingApi.merge_bills(%{
       main_order_id: mo,
       sub_order_ids: soi,
       user_id: context[:current_user].id
     })}
  end

  def cleared_bills(_, _, %{context: context}) do
    user = context[:current_user]
    cleared_bills = OrderingApi.get_cleared_bill(user.id)
    {:ok, cleared_bills}
  end

  def get_pending_orders(_, %{info: info}, _) do
    cond do
      info == "pending" ->
        {:ok, OrderingApi.get_pending_orders()}

      info == "incomplete" ->
        {:ok, OrderingApi.get_incomplete_orders()}

      info == "voided" ->
        {:ok, OrderingApi.get_voided_orders()}

      true ->
        {:error, "try again"}
    end
  end

  def create_split(_, %{table_id: ti}, %{context: context}) do
    {:ok, OrderingApi.create_empty_split(%{table_id: ti, user_id: context[:current_user].id})}
  end

  def update_split_order(_, %{order_id: oi, splitted_id: so, items: i}, _) do
    {:ok, OrderingApi.update_split_order(%{order_id: oi, splitted_order: so, items: i})}
  end

  def display_order_with_merged(_, args, _) do
    order_with_merged_info = OrderingApi.display_merged_bill(args.order_id)
    formatted_data = format_merged_order(order_with_merged_info)
    {:ok, formatted_data}
  end

  def format_merged_order(raw_data) do
    %Order{mergings: mergins_array, order_details: order_details_array, total: main_total} =
      raw_data

    IO.puts("from function")

    # mergins_array

    merged_detail_with_total =
      Enum.map(mergins_array, fn %{order_merged_detail: m_detail, sub_order: merged_order_info} ->
        detail_array =
          Enum.map(m_detail, fn %{item: item, sold_quantity: qty, sold_price: price} ->
            %{
              item_name: item.name,
              sold_quantity: qty,
              sold_price: price
            }
          end)

        %{
          detailed_sales: detail_array,
          total: merged_order_info.total
        }
      end)

    main_detail_with_total =
      Enum.map(order_details_array, fn %{item: item, sold_quantity: qty, sold_price: price} ->
        %{
          item_name: item.name,
          sold_quantity: qty,
          sold_price: price
        }
      end)

    gross_total =
      Enum.reduce(merged_detail_with_total, 0, fn %{total: total}, acc ->
        total + acc
      end)

    all_details =
      Enum.flat_map(Enum.map(merged_detail_with_total, fn map -> map.detailed_sales end), fn x ->
        x
      end)

    flatted_array = Enum.flat_map([all_details] ++ [main_detail_with_total], fn x -> x end)

    %{
      gross_total: gross_total + main_total,
      all_details: flatted_array
    }
  end

  def transform_order_details(details, dpt) do
    %{
      item: %Item{name: name, price: price},
      order: %Order{code: order_code, owner: owner_array},
      sold_quantity: qty,
      order_id: order_id
    } = details

    %{
      item_name: name,
      item_price: price,
      order_time: NaiveDateTime.to_string(NaiveDateTime.local_now()),
      code: order_code,
      owner_name: Enum.at(owner_array, 0).full_name,
      owner_username: Enum.at(owner_array, 0).username,
      order_id: order_id,
      quantity: qty,
      departement: dpt
    }
  end

  def transform_order_details_update(details, update, dpt) do
    %{
      item: %Item{name: name, price: price},
      order: %Order{code: order_code, owner: owner_array},
      order_id: order_id
    } = details

    %{
      item_name: name,
      item_price: price,
      order_time: NaiveDateTime.to_string(NaiveDateTime.local_now()),
      code: order_code,
      owner_name: Enum.at(owner_array, 0).full_name,
      owner_username: Enum.at(owner_array, 0).username,
      order_id: order_id,
      quantity: update.sold_quantity,
      departement: dpt
    }
  end

  def get_all_orders_from_waiter(a, %{username: username}, b) do
    waiter_order_with_details = OrderingApi.get_all_orders_from_waiter(username)
    formated_data = format_waiter_data(waiter_order_with_details)
    # {:ok, OrderingApi.get_all_orders_from_waiter(username)}
    {:ok, formated_data}
  end

  def get_all_split_bill_for_user(_, %{username: username}, _) do
    split_bill = OrderingApi.get_all_split_bill_for_user(username)

    tables_splitted =
      Enum.map(split_bill, fn %User{orders: orders} ->
        Enum.map(orders, fn %Order{table: table_data, id: splitted_id} ->
          %{
            table_id: table_data.id,
            table_number: table_data.number,
            splitted_id: splitted_id
          }
        end)
      end)

    {:ok, Enum.flat_map(tables_splitted, fn x -> x end)}
  end

  defp format_waiter_data(data) do
    %{full_name: full_name, id: id, orders: order_array} = data
    {:ok, orders} = Agent.start_link(fn -> [] end)

    Enum.each(
      order_array,
      fn %{
           code: code,
           id: order_id,
           ordered_at: ordered_at,
           status: status,
           table: table,
           total: order_total,
           split_status: split_status,
           merged_status: merged_status,
           order_details: details_array,
           payments: payments
         } ->
        orders_details =
          Enum.map(details_array, fn %{sold_price: price, sold_quantity: qty, item: item} ->
            %{
              item_name: item && item.name,
              item_id: item && item.id,
              quantity: qty,
              price: price
            }
          end)

        my_order_map = %{
          order_code: code,
          order_id: order_id,
          status: status,
          ordered_at: ordered_at,
          table_number: table && table.number,
          table_id: table && table.id,
          total_amount: order_total,
          split_status: split_status,
          merged_status: merged_status,
          details: orders_details,
          payments: length(payments) > 0 && Enum.at(payments, 0).order_paid
        }

        Agent.update(orders, fn list -> [my_order_map | list] end)
      end
    )

    response = Agent.get(orders, fn list -> list end)
    Agent.stop(orders)
    response
  end

  defp transform_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&format_error/1)
    |> Enum.map(fn
      {key, value} ->
        %{key: key, message: value}
    end)
  end

  @spec format_error(Ecto.Changeset.error()) :: String.t()
  defp format_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
