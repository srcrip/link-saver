defmodule LinkSaver.Links.Link do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "links" do
    field :url, :string
    field :title, :string
    field :description, :string
    field :image_url, :string
    field :site_name, :string
    field :raw_html, :string
    field :fetched_at, :utc_datetime
    field :fetch_error, :string
    field :favicon_url, :string

    belongs_to :user, LinkSaver.Users.User
    many_to_many :tags, LinkSaver.Links.Tag, join_through: "link_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(link, attrs \\ %{}) do
    link
    |> cast(attrs, [:url, :user_id])
    |> validate_required([:url, :user_id])
    |> normalize_url()
    |> assoc_constraint(:user)
  end

  def metadata_changeset(link, attrs \\ %{}) do
    link
    |> cast(attrs, [:title, :description, :image_url, :site_name, :raw_html, :fetched_at, :fetch_error, :favicon_url])
    |> validate_length(:title, max: 500)
    |> validate_length(:site_name, max: 200)
    |> validate_length(:image_url, max: 1000)
    |> validate_length(:favicon_url, max: 1000)
  end

  defp normalize_url(changeset) do
    case get_change(changeset, :url) do
      nil ->
        changeset

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
