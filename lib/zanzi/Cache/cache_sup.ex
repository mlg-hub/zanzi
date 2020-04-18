defmodule Zanzibloc.DepartementItemsCache do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, nil)
  end

  def init(_) do
    children = [
      Zanzibloc.Cache.BarCache
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
