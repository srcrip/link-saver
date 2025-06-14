defmodule LinkSaver.Repo.Migrations.AddTagsSystem do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:name, :user_id])
    create index(:tags, [:user_id])

    create table(:link_tags, primary_key: false) do
      add :link_id, references(:links, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:link_tags, [:link_id, :tag_id])
    create index(:link_tags, [:tag_id])
  end
end
