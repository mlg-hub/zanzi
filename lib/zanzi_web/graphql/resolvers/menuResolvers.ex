defmodule ZanziWeb.Resolvers.MenuResolver do
  alias Zanzibloc.Menu.{MenuApi}
  alias Zanzi.Repo
  import Absinthe.Resolution.Helpers, only: [on_load: 2]

  def menu_items(_, args, _) do
    {:ok, MenuApi.list_items(args)}
  end

  def create_item(_, %{input: params}, %{context: context}) do
    with {:ok, item} <- MenuApi.create_item(params) do
      {:ok, %{MenuApi_item: item}}
    end
  end

  def me(_, _, %{context: %{current_user: me}}) do
    {:ok, me}
  end

  def get_all_department(_, _, %{}) do
    departements = MenuApi.get_all_departement()

    cond do
      length(departements) >= 0 -> {:ok, departements}
      true -> {:error, "something went wrong"}
    end
  end

  # defp transform_errors(changeset) do
  #   changeset
  #   |> Ecto.Changeset.traverse_errors(&format_error/1)
  #   |> Enum.map(fn {key, value} ->
  #     %{key: key, message: value}
  #   end)
  # end

  # @spec format_error(Ecto.Changeset.error()) :: String.t()
  # defp format_error({msg, opts}) do
  #   Enum.reduce(opts, msg, fn {key, value}, acc ->
  #     String.replace(acc, "%{#{key}}", to_string(value))
  #   end)
  # end

  # defp error_details(changeset) do
  #   changeset
  #   |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
  # end

  # def items_for_category(category, args, %{context: %{loader: loader}}) do
  #   loader
  #   |> Dataloader.load(MenuApi, {:items, args}, category)
  #   |> on_load(fn loader ->
  #     items = Dataloader.get(loader, MenuApi, {:items, args}, category)
  #     {:ok, items}
  #   end)
  # end

  # # page427 old new page 451
  # def category_for_item(MenuApi_item, _, %{context: %{loader: loader}}) do
  #   loader
  #   |> Dataloader.load(MenuApi, :category, MenuApi_item)
  #   |> on_load(fn loader ->
  #     category = Dataloader.get(loader, MenuApi, :category, MenuApi_item)
  #     {:ok, category}
  #   end)
  # end

  def search(_, %{matching: term}, _) do
    {:ok, MenuApi.search(term)}
  end

  def get_all_from_department(_, %{id: id}, _) do
    result = MenuApi.menu_items(id)
    IO.inspect(result)
    {:ok, result}
  end
end
