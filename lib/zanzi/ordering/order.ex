defmodule Zanzibloc.Ordering.Order do
  use Ecto.Schema
  import Ecto.Changeset
  alias Zanzibloc.Ordering.{Order, Table, OrderOwner}
  import(Ecto.Query)

  schema "orders" do
    field(:code, :string, read_after_writes: true)
    field(:ordered_at, :utc_datetime, read_after_writes: true)
    field(:status, :string, read_after_writes: true)
    field(:total, :integer, read_after_writes: true)
    field(:merged_status, :integer)

    #####
    field(:split_status, :integer, default: 0)
    field(:filled, :integer)
    field(:splitted_from, :id)
    ###
    # has_many(:splits, )
    has_many(:order_details, Zanzibloc.Ordering.OrderDetail)
    has_many(:payments, Zanzibloc.Ordering.OrderPayment)
    has_many(:mergings, Zanzibloc.Ordering.OrderMerged)

    many_to_many(:owner, Zanzibloc.Account.User,
      join_through: OrderOwner,
      join_keys: [order_id: :id, current_owner: :id]
    )

    belongs_to(:table, Table)

    # embeds_many(:items, Zanzibloc.Ordering.Item)
    timestamps()
  end

  def create_split_changeset(%__MODULE__{} = order_split, attrs \\ %{}) do
    order_split
    |> cast(attrs, [:table_id, :split_status, :filled, :status])
    |> validate_required([:table_id, :split_status])
    |> put_change(:code, make_ordercode())
  end

  def update_split_changeset(%__MODULE__{} = order_split, attrs) do
    order_split
    |> cast(attrs, [:total, :filled, :splitted_from])
  end

  def changeset(%__MODULE__{} = order, attrs \\ %{}) do
    order
    |> cast(attrs, [:total, :table_id])
    |> put_change(:code, make_ordercode())

    # |> cast_embed(:items)

    # |> validate_required([:code, :ordered_at, :user, :status])
  end

  def add_item_changeset(%__MODULE__{} = order, attrs \\ %{}) do
    order
    |> cast(attrs, [:total])
    |> validate_required([:total])
  end

  def update_changeset(%__MODULE__{} = order, attrs) do
    order
    |> cast(attrs, [:status, :split_status, :merged_status, :total])
  end

  def update_main_split_changeset(%__MODULE__{} = order, attrs) do
    order
    |> cast(attrs, [:status, :split_status, :merged_status, :total])
    |> put_change(:total, attrs.total)
  end

  defp make_ordercode() do
    today = Date.to_iso8601(Date.utc_today(), :basic)
    day = Date.day_of_week(Date.utc_today()) |> Integer.to_string()

    case Zanzi.Repo.one(from(x in Order, order_by: [desc: x.id], limit: 1)) do
      %Order{} = order ->
        indice =
          String.split(order.code, "/")
          |> Enum.reverse()
          |> Enum.at(0)

        IO.inspect(indice)
        current_indice = String.to_integer(indice) + 1

        code = "#{today}/#{day}/#{current_indice}"
        IO.inspect(code)
        code

      nil ->
        "#{today}/#{day}/0"
    end
  end
end
