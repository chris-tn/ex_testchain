defmodule WebApiWeb.IndexController do
  use WebApiWeb, :controller

  def index(conn, _params) do
    conn
    |> json(%{status: 0, message: "Welcome to ExTestchain !"})
  end
end
