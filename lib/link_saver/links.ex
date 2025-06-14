defmodule LinkSaver.Links do
  @moduledoc false
  import Ecto.Query

  alias LinkSaver.Links.Link
  alias LinkSaver.Links.Fetcher
  alias LinkSaver.Repo

  def get_link(id) do
    Repo.get(Link, id)
  end

  def list_links do
    Repo.all(from(l in Link, order_by: [desc: l.inserted_at]))
  end

  def list_links_for_user(user_id) do
    Repo.all(from(l in Link, where: l.user_id == ^user_id, order_by: [desc: l.inserted_at]))
  end

  def create_link(attrs) do
    %Link{}
    |> Link.changeset(attrs)
    |> Repo.insert()
  end

  def update_link(link, attrs) do
    link
    |> Link.changeset(attrs)
    |> Repo.update()
  end

  def delete_link(link) do
    Repo.delete(link)
  end

  def update_link_metadata(link, metadata) do
    link
    |> Link.metadata_changeset(metadata)
    |> Repo.update()
  end

  def fetch_and_update_metadata(link_id) do
    case get_link(link_id) do
      nil -> 
        {:error, :not_found}

      link ->
        case Fetcher.fetch_metadata(link.url) do
          {:ok, metadata} ->
            update_link_metadata(link, metadata)

          {:error, reason} ->
            # Store the error in the database
            error_metadata = %{
              fetch_error: "#{reason}",
              fetched_at: DateTime.utc_now()
            }
            update_link_metadata(link, error_metadata)
        end
    end
  end
end
