defmodule LinkSaver.Links do
  @moduledoc false
  import Ecto.Query

  alias LinkSaver.Links.Fetcher
  alias LinkSaver.Links.Link
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

  def search_links_for_user(user_id, search_term) when is_binary(search_term) and search_term != "" and byte_size(search_term) >= 2 do
    # Clean and prepare search term for tsquery
    cleaned_term = 
      search_term
      |> String.replace(~r/[^\w\s]/u, " ")
      |> String.split()
      |> Enum.filter(&(String.length(&1) > 0))
      |> Enum.map(&"#{&1}:*")
      |> Enum.join(" & ")

    # Return early if no valid search terms after cleaning
    if cleaned_term == "" do
      list_links_for_user(user_id)
    else
      query = from l in Link,
        where: l.user_id == ^user_id and fragment("? @@ to_tsquery('english', ?)", l.search_vector, ^cleaned_term),
        order_by: [desc: fragment("ts_rank(?, to_tsquery('english', ?))", l.search_vector, ^cleaned_term)]
      
      Repo.all(query)
    end
  end

  def search_links_for_user(user_id, _), do: list_links_for_user(user_id)

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
