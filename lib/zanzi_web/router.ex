defmodule ZanziWeb.Router do
  use ZanziWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(ZanziWeb.Context)
  end

  scope "/", ZanziWeb do
    pipe_through(:browser)
    get("/", AdminController, :index)
    resources("/sessions", SessionController, only: [:new, :create, :delete])

    scope "/menu" do
      get("/items", MenuItemsController, :items_all)
      get("/categories", MenuItemsController, :cats_all)
      get("/depertements", MenuItemsController, :depts_all)
      post("/new_item", MenuItemsController, :new_item)
    end

    scope "/orders" do
      get("/cleared", OrderController, :cleared)
      get("/pending", OrderController, :pending)
      get("/voided", OrderController, :voided)
      get("/unpaid", OrderController, :unpaid)
      get("/complementary", OrderController, :complementary)
      get("/remain", OrderController, :remain)
      get("/detail/:id", OrderController, :detail)
      post("/filter_dates", OrderController, :filter_date)
      post("/filter_shifts", OrderController, :filter_shift)
    end

    scope "/departement" do
      get("/stats_bar", DepartementController, :stats_bar)
      get("/stats_coffee", DepartementController, :stats_coffee)
      get("/stats_kitchen", DepartementController, :stats_kitchen)
      get("/stats_restaurant", DepartementController, :stats_restaurant)
      get("/stats_mini_bar", DepartementController, :stats_mini_bar)
      post("/filter_date", DepartementController, :filter_date)
      post("/filter_shift", DepartementController, :filter_shift)
    end
  end

  scope "/api" do
    pipe_through(:api)

    forward("/graphiql", Absinthe.Plug.GraphiQL,
      schema: ZanziWeb.Schema,
      # interface: :playground,
      socket: ZanziWeb.UserSocket
    )

    forward("/", Absinthe.Plug, schema: ZanziWeb.Schema)
  end

  # Other scopes may use custom stacks.
  # scope "/api", ZanziWeb do
  #   pipe_through :api
  # end
end
