defmodule LinkSaver.Repo.Migrations.AddLinks do
  use Ecto.Migration

  def change do
    create table(:links) do
      add :url, :text
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end
  end
end
