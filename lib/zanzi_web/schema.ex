defmodule ZanziWeb.Schema do
  use Absinthe.Schema
  alias __MODULE__.Middleware

  alias ZanziWeb.Resolvers.{MenuResolver, AccountsResolvers, OrderingResolvers}
  alias Zanzibloc.Account.User

  def middleware(middleware, field, object) do
    middleware
    |> apply(:errors, field, object)
    |> apply(:get_string, field, object)
    |> apply(:debug, field, object)
  end

  defp apply(middleware, :errors, _field, %{identifier: :mutation}) do
    middleware ++ [Middleware.ChangesetErrors]
  end

  # defp apply([], :get_string, field, %{identifier: :allergy_info}) do
  #   [{Absinthe.Middleware.MapGet, to_string(field.identifier)}]
  # end

  defp apply(middleware, :debug, _field, _object) do
    if System.get_env("DEBUG") do
      [{Middleware.Debug, :start}] ++ middleware
    else
      middleware
    end
  end

  defp apply(middleware, _, _, _) do
    middleware
  end

  def plugins do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end

  def dataloader() do
    alias Zanzibloc.Menu.MenuApi

    Dataloader.new()
    |> Dataloader.add_source(MenuApi, MenuApi.data())
  end

  def orderingDataLoader do
    alias Zanzibloc.Ordering.OrderingApi

    Dataloader.new()
    |> Dataloader.add_source(OrderingApi, OrderingApi.data())
  end

  def context(ctx) do
    IO.puts("ici ndani context")
    IO.inspect(ctx)
    Map.put(ctx, :loader, dataloader())
  end

  import_types(__MODULE__.MenuTypes)
  import_types(__MODULE__.OrderingTypes)
  import_types(__MODULE__.ScalarTypes)
  import_types(__MODULE__.AccountTypes)
  import_types(Absinthe.Phoenix.Types)

  query do
    import_fields(:menu_queries)

    # field :get_all_categries, list_of(:categorie) do
    #   resolve(&MenuResolver.get_all_categories/3)
    # end
    field :display_order_with_merge, :merged_detail_with_total do
      arg(:order_id, :id)
      resolve(&OrderingResolvers.display_order_with_merged/3)
    end

    field :get_all_request_void, list_of(:order) do
      resolve(&OrderingResolvers.get_all_request_void/3)
    end

    field :get_pending_orders, list_of(:order) do
      arg(:info, :string)
      arg(:date, :string)
      resolve(&OrderingResolvers.get_pending_orders/3)
    end

    field :get_all_stats, :sales_stats do
      arg(:date, :string)
      resolve(&OrderingResolvers.get_sales_stats/3)
    end

    field :get_order_simple_details, list_of(:simple_order_detail) do
      arg(:order_id, :id)
      resolve(&OrderingResolvers.get_order_details/3)
    end

    field :get_all_split_bill_for_user, list_of(:open_split_bill_list) do
      arg(:username, :string)
      resolve(&OrderingResolvers.get_all_split_bill_for_user/3)
    end

    field :get_all_department, list_of(:departement) do
      resolve(&MenuResolver.get_all_department/3)
    end

    field :orders_for_waiter, list_of(:waiter_order) do
      arg(:username, :string)
      resolve(&OrderingResolvers.get_all_orders_from_waiter/3)
    end

    field :get_cleared_bills, list_of(:order) do
      arg(:date, :string)
      resolve(&OrderingResolvers.cleared_bills/3)
    end

    field :get_all_from_department, list_of(:department_detail) do
      arg(:id, :id)
      resolve(&MenuResolver.get_all_from_department/3)
    end

    field :get_all_tables, list_of(:table_order) do
      resolve(&OrderingResolvers.get_all_tables/3)
    end

    field :search, list_of(:search_result) do
      arg(:matching, non_null(:string))
      resolve(&MenuResolver.search/3)
    end

    field :me, :user do
      middleware(Middleware.Authorize, :auth)
      resolve(&MenuResolver.me/3)
    end

    field(:user_list, list_of(:user)) do
      arg(:role, list_of(:string))
      resolve(&AccountsResolvers.list_users/3)
    end
  end

  mutation do
    field :merge_bills, :response_status do
      arg(:main_order_id, :id)
      arg(:sub_order_ids, list_of(:id))
      resolve(&OrderingResolvers.merge_bills/3)
    end

    field :set_printed, :response_status do
      arg(:order_id, :id)
      resolve(&OrderingResolvers.set_printed/3)
    end

    field :send_transfer_request, :response_status do
      arg(:order_id, non_null(:id))
      arg(:receiver_id, non_null(:string))
      resolve(&OrderingResolvers.send_transfer_request/3)
    end

    field :create_empty_split_bill, :response_status do
      arg(:table_id, non_null(:id))
      resolve(&OrderingResolvers.create_split/3)
    end

    field :update_split_bill, :response_status do
      arg(:order_id, non_null(:id))
      arg(:items, list_of(:order_item_input))
      arg(:splitted_id, non_null(:id))
      resolve(&OrderingResolvers.update_split_order/3)
    end

    field :accept_transfer_request, :response_status do
      arg(:order_id, non_null(:id))
      resolve(&OrderingResolvers.accept_transfer_request/3)
    end

    field :reject_transfer_request, :response_status do
      arg(:order_id, non_null(:id))
      resolve(&OrderingResolvers.reject_transfer_request/3)
    end

    # field :open_cashier_shift do
    # end

    # field :close_cashier_shif do
    # end

    field :login, :session do
      arg(:username, non_null(:string))
      arg(:password, non_null(:string))
      resolve(&AccountsResolvers.login/3)

      middleware(fn res, _ ->
        with %{value: %{user: user}} <- res do
          %{res | context: Map.put(res.context, :current_user, user)}
        end
      end)
    end

    field :void_order, :response_status do
      arg(:order_id, :id)
      arg(:reason, :string)
      resolve(&OrderingResolvers.void_order/3)
    end

    field :send_void_request, :response_status do
      arg(:order_id, :id)
      resolve(&OrderingResolvers.send_void_request/3)
    end

    field :prepare_order, :order_result do
      arg(:id, non_null(:id))
      middleware(Middleware.Authorize, :auth)
      resolve(&OrderingResolvers.prepare_order/3)
    end

    field :pay_order, :response_status do
      arg(:order_id, non_null(:id))
      arg(:order_paid, :integer)
      arg(:order_type, :string)
      middleware(Middleware.Authorize, :auth)
      resolve(&OrderingResolvers.pay_order/3)
    end

    # field :create_menu_item, :menu_item_result do
    #   arg(:input, non_null(:menu_item_input))
    #   middleware(Middleware.Authorize)
    #   resolve(&Resolvers.Menu.create_item/3)
    # end

    field :place_order, :response_status do
      arg(:input, non_null(:place_order_input))
      arg(:table, non_null(:integer))
      middleware(Middleware.Authorize, :auth)
      resolve(&OrderingResolvers.place_order/3)
    end

    field :update_place_order, :response_status do
      arg(:input, non_null(:place_order_input))
      arg(:order_id, non_null(:id))
      middleware(Middleware.Authorize, :auth)
      resolve(&OrderingResolvers.update_place_order/3)
    end
  end

  subscription do
    field(:commande, :order_sub_resp) do
      arg(:dest, :string)

      config(fn args, _ ->
        # {:ok, topic: "174"}
        # case context[:current_user] do
        #   %User{position: position} = user ->
        #     position = Enum.at(position, 0).id

        {:ok, topic: args.dest}

        # _ ->
        #   {:error, "go and login"}
        # end
      end)

      resolve(fn root, _, _ ->
        {:ok, %{route: Enum.at(root, 0), details: Enum.at(root, 1)}}
      end)
    end
  end

  scalar :custom_decimal do
    parse(fn
      %{value: value}, _ -> Decimal.parse(value)
      _, _ -> :error
    end)

    serialize(&to_string/1)
  end

  scalar :custom_naive_date do
    parse(
      fn input ->
        # Parsing logic here
        with %Absinthe.Blueprint.Input.String{value: value} <- input,
             {:ok, date} <- Date.to_iso8601(NaiveDateTime.to_date(value)) do
          IO.inspect(date)
          {:ok, date}
        else
          _ -> :error
        end
      end

      # case(Date.from_iso8601(input.value)) do
      #   {:ok, date} -> {:ok, date}
      #   _ -> :error
      # end
    )

    serialize(fn date ->
      # Serialization logic here
      date
    end)
  end

  scalar :custom_date do
    parse(
      fn input ->
        # Parsing logic here
        with %Absinthe.Blueprint.Input.String{value: value} <- input,
             {:ok, date} <- Date.from_iso8601(value) do
          {:ok, date}
        else
          _ -> :error
        end
      end

      # case(Date.from_iso8601(input.value)) do
      #   {:ok, date} -> {:ok, date}
      #   _ -> :error
      # end
    )

    serialize(fn date ->
      # Serialization logic here
      Date.to_iso8601(date)
    end)
  end

  enum(:sort_order) do
    value(:asc)
    value(:desc)
  end

  object :input_error do
    field(:key, non_null(:string))
    field(:message, non_null(:string))
  end
end
