defmodule ZanziWeb.Schema.OrderingTypes do
  use Absinthe.Schema.Notation

  input_object :order_item_input do
    field(:id, non_null(:id))
    field(:quantity, non_null(:integer))
  end

  input_object :place_order_input do
    field(:items, non_null(list_of(non_null(:order_item_input))))
  end

  object :order_result do
    field(:order, :order)
    field(:details, list_of(:order_detail))
    field(:errors, list_of(:input_error))
  end

  object :response_status do
    field(:status, :string)
    field(:error, list_of(:input_error))
  end

  object :order_and_detail do
    field(:order, :order)
    field(:details, list_of(:order_detail))
  end

  object :user_order do
    field(:full_name, :string)
    field(:id, :string)
    field(:orders, list_of(:waiter_order))
  end

  # object :split_list, list_of(:open_split_bill_list) do
  # end

  object :open_split_bill_list do
    field(:table_id, non_null(:id))
    field(:table_number, :integer)
    field(:splitted_id, non_null(:id))
  end

  object :sales_stats do
    field :bar, :integer
    field :kitchen, :integer
    field :mini_bar, :integer
    field :restaurant, :integer
    field :total, :integer
    field :shifts, list_of(:shifts)
  end

  object :shifts do
    field :id, :id
    field :shift_start, :custom_date_time
    field :shift_end, :custom_date_time
  end

  object :waiter_order do
    field(:order_id, :id)
    field(:order_code, :string)
    field(:ordered_at, :custom_naive_date)
    field(:payments, type: :payment_field)
    field(:status, :string)
    field(:split_status, :integer)
    field(:merged_status, :integer)
    field(:table_number, :integer)
    field(:table_id, :integer)
    field(:order_category, :integer)
    field(:total_amount, :integer)
    field(:details, list_of(:waiter_order_details))
  end

  # object :payments do
  # end

  object :waiter_order_details do
    field(:item_name, :string)
    field(:item_id, :id)
    field(:price, :integer)
    field(:quantity, :integer)
  end

  object :order_payment do
    field :order, :order
    field :order_total, :integer
    field :order_paid, :integer
    field :inserted_at, :custom_naive_date
  end

  object :order do
    field(:id, :id)
    field(:code, :string)
    field(:inserted_at, :custom_naive_date)
    field :merged_status, :integer
    field :split_status, :integer
    field :status, :string
    field :payments, list_of(:order_payment)

    field :order_details, list_of(:order_detail) do
      resolve(fn parent, _, _ ->
        alias Zanzi.Repo
        fechedData = Repo.all(Ecto.assoc(parent, :order_details))
        {:ok, fechedData}
      end)
    end

    field(:owner, list_of(:user))
    field :total, :integer
    field :table, :table
  end

  object :table do
    field :id, :string
    field :number, :integer
  end

  object :order_sub_resp do
    field :route, :route_map
    field :details, list_of(:order_detail)
  end

  object :route_map do
    field :route, :string
  end

  object :order_detail do
    field(:item_name, :string)
    field(:item_price, :integer)
    field(:code, :string)
    field(:order_id, :integer)
    field(:order_time, :custom_naive_date)
    field(:owner_name, :string)
    field(:quantity, :integer)
  end

  object :simple_order_detail do
    field :id, :id
    field :code, :string
    field :paid, :boolean
    field :order_paid, :integer
    field :name, :string
    field :sold_price, :integer
    field :sold_quantity, :integer
    field :total, :integer
  end

  object :merged_detail_with_total do
    field(:gross_total, :integer)
    field(:all_details, list_of(:merged_detail_item))
  end

  object :merged_detail_item do
    field(:item_name, :integer)
    field(:sold_price, :decimal)
    field(:sold_quantity, :integer)
  end

  object :order_item do
    field(:name, :string)
    field(:quantity, :integer)
  end
end
