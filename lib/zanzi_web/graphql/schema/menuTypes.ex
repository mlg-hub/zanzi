defmodule ZanziWeb.Schema.MenuTypes do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers
  alias ZanziWeb.Resolvers
  alias Zanzibloc.Menu.{Category, Item, Departement, MenuApi}
  @desc "Filtering options for the menu item list"

  input_object :menu_item_filter do
    @desc "Matching a name"
    field(:name, :string)

    @desc "Matching a category name"
    field(:category, :string)

    @desc "Matching a tag"
    field(:tag, :string)

    @desc "Priced above a value"
    field(:priced_above, :float)

    @desc "Priced below a value"
    field(:priced_below, :float)

    @desc "Added to the menu before this date"
    field(:added_before, :date)

    @desc "Added to the menu after this date"
  end

  input_object :menu_item_input do
    field(:name, non_null(:string))
    field(:departement_id, non_null(:id))
    field(:price, non_null(:decimal))
    field(:category_id, non_null(:id))
  end

  # union :search_result do
  #   types([:menu_item, :category])

  #   resolve_type(fn
  #     %PlateSlate.Menu.Item{}, _ ->
  #       :menu_item

  #     %PlateSlate.Menu.Category{}, _ ->
  #       :category

  #     _, _ ->
  #       nil
  #   end)
  # end

  interface :search_result do
    field(:name, :string)

    resolve_type(fn
      %Item{}, _ ->
        :menu_item

      %Category{}, _ ->
        :category

      _, _ ->
        nil
    end)
  end

  interface :department_detail do
    field(:name, :string)
    field(:id, :id)
    field(:departement_id, :id)

    resolve_type(fn
      %Item{}, _ ->
        :menu_item

      %Category{}, _ ->
        :category

      _, _ ->
        nil
    end)
  end

  object :menu_item_result do
    field(:menu_item, :menu_item)
    field(:errors, list_of(:input_error))
  end

  # object :category do
  #   interfaces([:search_result])

  #   field(:name, :string)
  #   field(:description, :string)

  #   field :items, list_of(:menu_item) do
  #     arg(:filter, :menu_item_filter)
  #     arg(:order, type: :sort_order, default_value: :asc)
  #     resolve(&Resolvers.Menu.items_for_category/3)
  #   end
  # end

  object :category do
    interfaces([:search_result, :department_detail])

    field(:name, :string)
    field(:id, :id)
    field(:departement_id, :id)

    field :items, list_of(:menu_item) do
      arg(:filter, :menu_item_filter)
      arg(:order, type: :sort_order, default_value: :asc)
      resolve(dataloader(MenuApi, :items))
    end
  end

  object :table_order do
    field(:number, :integer)
    field(:id, :id)
  end

  object :menu_queries do
    field :menu_items, list_of(:menu_item) do
      arg(:filter, :menu_item_filter)
      arg(:order, type: :sort_order, default_value: :asc)
      resolve(&Resolvers.MenuResolver.menu_items/3)
    end
  end

  # object :menu_item do
  #   interfaces([:search_result])
  #   field(:id, :id)
  #   field(:price, :decimal)
  #   field(:name, :string)
  #   field(:description, :string)
  #   field(:added_on, :date)
  #   field(:allergy_info, list_of(:allergy_info))

  #   field(:category, :category) do
  #     resolve(&Resolvers.Menu.category_for_item/3)
  #   end
  # end

  object :menu_item do
    interfaces([:search_result, :department_detail])
    field(:name, :string)
    field(:id, :id)
    field(:departement_id, :id)
    field(:price, :decimal)
    field(:added_on, :date)
    field(:category, :category, resolve: dataloader(MenuApi))
  end

  object :departement do
    field(:name, :string)
    field(:id, :id)
  end

  object :allergy_info do
    field :allergen, :string do
      resolve(fn parent, _, _ ->
        {:ok, Map.get(parent, "allergen")}
      end)
    end

    field :severity, :string do
      resolve(fn parent, _, _ ->
        {:ok, Map.get(parent, "severity")}
      end)
    end
  end
end
