defmodule LinkSaver.Links.Link do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "links" do
    field :url, :string

    belongs_to :user, LinkSaver.Users.User

    timestamps(type: :utc_datetime)
  end

  def changeset(link, attrs \\ %{}) do
    link
    |> cast(attrs, [:url, :user_id])
    |> validate_required([:url, :user_id])
    |> assoc_constraint(:user)
  end
end
