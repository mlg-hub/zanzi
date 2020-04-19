defmodule Zanzibloc.DepartementItemsCache do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil)
  end

  def init(_) do
    children = [
      Zanzibloc.Cache.UserCache,
      Zanzibloc.Cache.BarCache,
      Zanzibloc.Cache.KitchenCache,
      Zanzibloc.Cache.CoffeeCache,
      Zanzibloc.Cache.ToCoffee,
      Zanzibloc.Cache.ToprintBar,
      Zanzibloc.Cache.ToKitchen
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
