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

    scope "/orders" do
      get "/cleared", OrderController, :cleared
      get "/pending", OrderController, :pending
      get "/voided", OrderController, :voided
      get "/incomplete", OrderController, :incomplete
      get "/detail/:id", OrderController, :detail
      post "/filter_date", OrderController, :filter_date
    end

    scope "/departement" do
      get "/stats_bar", DepartementController, :stats_bar
      get "/stats_coffee", DepartementController, :stats_coffee
      get "/stats_kitchen", DepartementController, :stats_kitchen
      post "/filter_date", DepartementController, :filter_date
    end
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
