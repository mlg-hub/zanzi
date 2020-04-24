defmodule ZanziWeb.CommandeChannel do
  use ZanziWeb, :channel
  alias Zanzibloc.Cache.{ToKitchen, ToCoffee, ToprintBar}

  # alias Zanzibloc.Cache.{ToKitchen, ToCoffee, ToprintBar}

  def join("commande:" <> dpt_name, _params, socket) do
    {:ok, assign(socket, :active_dpt, dpt_name)}
  end

  def handle_in("gotpaper", %{"clear" => payload, "dpt" => dpt}, socket) do
    case dpt do
      "bar" ->
        Zanzibloc.Cache.ToprintBar.update_cache_from_manual(payload)

      "kitchen" ->
        Zanzibloc.Cache.ToKitchen.update_cache_from_manual(payload)

      "coffee" ->
        Zanzibloc.Cache.ToCoffee.update_cache_from_manual(payload)
    end

    {:reply, :ok, socket}
  end

  def handle_in("fetch_cache", %{"dpt" => dpt}, socket) do
    case dpt do
      "bar" ->
        # fetch pending printing from cache bar

        cache = ToprintBar.fetch_cache_print()

        ZanziWeb.Endpoint.broadcast!("commande:bar", "fetched_cache", %{
          caches: cache
        })

        {:reply, :ok, socket}

      "kitchen" ->
        # fetch pending printing from cache bar
        cache = ToKitchen.fetch_cache_print()

        ZanziWeb.Endpoint.broadcast!("commande:kitchen", "fetched_cache", %{
          caches: cache
        })

        {:reply, :ok, socket}

      "coffee" ->
        # fetch pending printing from cache bar
        cache = ToCoffee.fetch_cache_print()

        ZanziWeb.Endpoint.broadcast!("commande:coffee", "fetched_cache", %{
          caches: cache
        })

        {:reply, :ok, socket}
    end
  end
end
