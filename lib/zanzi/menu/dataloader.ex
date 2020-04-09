defmodule ZanziWeb.LoadData do
  import Ecto.Query, warn: false
  alias Zanzi.Repo

  def dataloader_source() do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  def query(Item, args) do
  end
end
