defmodule ZanziWeb.UserSocket do
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket, schema: ZanziWeb.Schema

  ## Channels
  # channel "room:*", ZanziWeb.RoomChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(params, socket, _connect_info) do
    IO.inspect("")
    IO.inspect(params)
    IO.inspect(socket)
    IO.inspect(params)

    with %{"authorization" => token} <- params do
      token = params.authorization && params.authorization

      with "Bearer " <> tok <- token,
           {:ok, data} <- ZanziWeb.Auth.TokenAuthentication.verify(tok),
           %{user_id: user_id} <- data do
        current_user = Zanzibloc.Account.AccountApi.lookup(user_id)
        IO.puts("koto goooooot")
        IO.inspect(current_user)

        # current_user = current_user(params)

        socket =
          Absinthe.Phoenix.Socket.put_options(socket,
            context: %{
              current_user: current_user
            }
          )

        {:ok, socket}
      else
        _ -> {:ok, socket}
      end
    else
      _ -> {:ok, socket}
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     ZanziWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil
end
