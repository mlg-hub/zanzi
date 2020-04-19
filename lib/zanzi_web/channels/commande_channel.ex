defmodule ZanziWeb.CommandeChannel do
  use ZanziWeb, :channel

  # alias Zanzibloc.Cache.{ToKitchen, ToCoffee, ToprintBar}

  def join("commande:" <> dpt_name, _params, socket) do
    {:ok, assign(socket, :active_dpt, dpt_name)}
  end
end
