defmodule LinkSaver.Repo.Migrations.AddFaviconUrlToLinks do
  use Ecto.Migration

  def change do
    alter table(:links) do
      add :favicon_url, :string, size: 1000
    end
  end
end
