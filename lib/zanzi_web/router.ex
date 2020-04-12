defmodule ZanziWeb.Router do
  use ZanziWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ZanziWeb.Context
  end

  scope "/admin", ZanziWeb do
    pipe_through :browser

    get "/", AdminController, :index
  end

  scope "/" do
    pipe_through :api

    forward "/api", Absinthe.Plug, schema: ZanziWeb.Schema

    forward "/graphiql", Absinthe.Plug.GraphiQL,
      schema: ZanziWeb.Schema,
      # interface: :playground,
      socket: ZanziWeb.UserSocket
  end

  # Other scopes may use custom stacks.
  # scope "/api", ZanziWeb do
  #   pipe_through :api
  # end
end
