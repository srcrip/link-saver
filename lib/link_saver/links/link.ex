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
    |> normalize_url()
    |> assoc_constraint(:user)
  end

  defp normalize_url(changeset) do
    case get_change(changeset, :url) do
      nil -> changeset
      url -> 
        normalized_url = 
          if String.starts_with?(url, ["http://", "https://"]) do
            url
          else
            "https://" <> url
          end
        put_change(changeset, :url, normalized_url)
    end
  end
end
