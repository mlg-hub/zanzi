defmodule ZanziWeb.CommandeChannel do
  use ZanziWeb, :channel
  alias Zanzibloc.Cache.{ToKitchen, ToprintMiniBar, ToprintBar, ToprintRestaurant}

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

      "resto-bar" ->
        Zanzibloc.Cache.ToprintRestaurant.update_cache_from_manual(payload)
        Zanzibloc.Cache.ToprintMiniBar.update_cache_from_manual(payload)
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

      "resto-bar" ->
        # fetch pending printing from cache bar
        cache_resto = ToprintRestaurant.fetch_cache_print()
        cache_minibar = ToprintMiniBar.fetch_cache_print()
        cache = cache_minibar ++ cache_resto

        ZanziWeb.Endpoint.broadcast!("commande:resto-bar", "fetched_cache", %{
          caches: cache
        })

        {:reply, :ok, socket}
    end
  end

  def handle_in("count_pending_cache", %{"dpt" => dpt}, socket) do
    case dpt do
      "bar" ->
        # fetch pending printing from cache bar

        cache = ToprintBar.fetch_cache_count()

        ZanziWeb.Endpoint.broadcast!("commande:bar", "count_cache", %{
          count: cache
        })

        {:reply, :ok, socket}

      "kitchen" ->
        # fetch pending printing from cache bar
        cache = ToKitchen.fetch_cache_count()

        ZanziWeb.Endpoint.broadcast!("commande:kitchen", "count_cache", %{
          count: cache
        })

        {:reply, :ok, socket}

      "restaurant" ->
        # fetch pending printing from cache bar
        cache = ToprintRestaurant.fetch_cache_count()

        ZanziWeb.Endpoint.broadcast!("commande:restaurant", "count_cache", %{
          count: cache
        })

        {:reply, :ok, socket}

      "minibar" ->
        # fetch pending printing from cache bar
        cache = ToprintMiniBar.fetch_cache_count()

        ZanziWeb.Endpoint.broadcast!("commande:minibar", "count_cache", %{
          count: cache
        })

        {:reply, :ok, socket}
    end
  end
end
