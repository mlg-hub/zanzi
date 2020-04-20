defmodule ZanziWeb.DepartementChannel do
  use ZanziWeb, :channel
  alias ZanziWeb.Presence
  alias Zanzibloc.Cache.{ToKitchen, ToCoffee, ToprintBar}

  def join("departement:zanzi", %{"departement" => dpt_name}, socket) do
    send(self(), :after_join)

    # get pending print paper if any

    case dpt_name do
      "bar" ->
        # fetch pending printing from cache bar

        pending_printing = ToprintBar.fetch_pending_print()

        {:ok, %{active: true, pending: pending_printing}, assign(socket, :active_dpt, dpt_name)}

      "kitchen" ->
        # fetch pending printing from cache bar
        pending_printing = ToKitchen.fetch_pending_print()
        {:ok, %{active: true, pending: pending_printing}, assign(socket, :active_dpt, dpt_name)}

      "coffee" ->
        # fetch pending printing from cache bar
        pending_printing = ToCoffee.fetch_pending_print()
        {:ok, %{active: true, pending: pending_printing}, assign(socket, :active_dpt, dpt_name)}
    end

    # {:error, %{error: ""}}
  end

  def handle_info(:after_join, socket) do
    push(socket, "presence_state", Presence.list(socket))
    dpt_name = socket.assigns[:active_dpt]
    IO.puts("in after join")
    IO.inspect(dpt_name)

    {:ok, _} =
      Presence.track(socket, "departement:#{dpt_name}", %{
        active: true
      })

    IO.puts("here is the presence list After")
    IO.inspect(Presence.list(socket))
    {:noreply, socket}
  end
end
