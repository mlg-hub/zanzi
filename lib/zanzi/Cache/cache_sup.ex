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
      # Zanzibloc.Cache.CoffeeCache,
      Zanzibloc.Cache.Restaurant,
      Zanzibloc.Cache.MiniBar,
      Zanzibloc.Cache.ToprintRestaurant,
      Zanzibloc.Cache.ToprintMiniBar,
      Zanzibloc.Cache.ToprintBar,
      Zanzibloc.Cache.ToKitchen,
      Zanzibloc.Cache.VoidSecret
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
