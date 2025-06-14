defmodule LinkSaver.Repo.Migrations.AddMetadataToLinks do
  use Ecto.Migration

  def change do
    alter table(:links) do
      add :title, :string, size: 500
      add :description, :text
      add :image_url, :string, size: 1000
      add :site_name, :string, size: 200
      add :raw_html, :text
      add :fetched_at, :utc_datetime
      add :fetch_error, :text
    end
  end
end
