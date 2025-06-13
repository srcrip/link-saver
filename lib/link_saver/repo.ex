defmodule LinkSaver.Repo do
  use Ecto.Repo,
    otp_app: :link_saver,
    adapter: Ecto.Adapters.Postgres
end
