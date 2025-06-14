defmodule LinkSaver.Links.Tag do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "tags" do
    field :name, :string
    belongs_to :user, LinkSaver.Users.User
    many_to_many :links, LinkSaver.Links.Link, join_through: "link_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 50)
    |> trim_name()
    |> unique_constraint([:name, :user_id])
  end

  defp trim_name(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.trim(name))
    end
  end
end
