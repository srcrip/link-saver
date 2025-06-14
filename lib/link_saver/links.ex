defmodule LinkSaver.Links do
  @moduledoc false
  import Ecto.Query

  alias LinkSaver.Links.AutoTagger
  alias LinkSaver.Links.Fetcher
  alias LinkSaver.Links.Link
  alias LinkSaver.Links.Tag
  alias LinkSaver.Repo

  def get_link(id) do
    Repo.get(Link, id)
  end

  def list_links do
    Repo.all(from(l in Link, order_by: [desc: l.inserted_at]))
  end

  def list_links_for_user(user_id) do
    Repo.all(from(l in Link, where: l.user_id == ^user_id, order_by: [desc: l.inserted_at], preload: [:tags]))
  end

  def search_links_for_user(user_id, search_term)
      when is_binary(search_term) and search_term != "" and byte_size(search_term) >= 2 do
    # Clean and prepare search term for tsquery
    cleaned_term =
      search_term
      |> String.replace(~r/[^\w\s]/u, " ")
      |> String.split()
      |> Enum.filter(&(String.length(&1) > 0))
      |> Enum.map_join(" & ", &"#{&1}:*")

    # Return if no valid search terms after cleaning
    if cleaned_term == "" do
      list_links_for_user(user_id)
    else
      query =
        from l in Link,
          where: l.user_id == ^user_id and fragment("? @@ to_tsquery('english', ?)", l.search_vector, ^cleaned_term),
          order_by: [desc: fragment("ts_rank(?, to_tsquery('english', ?))", l.search_vector, ^cleaned_term)],
          preload: [:tags]

      Repo.all(query)
    end
  end

  def search_links_for_user(user_id, _), do: list_links_for_user(user_id)

  def list_links_for_user_filtered_by_tags(user_id, tag_names) when is_list(tag_names) and length(tag_names) > 0 do
    Repo.all(
      from l in Link,
      join: t in assoc(l, :tags),
      where: l.user_id == ^user_id and t.name in ^tag_names,
      group_by: l.id,
      having: count(t.id) == ^length(tag_names),
      order_by: [desc: l.inserted_at],
      preload: [:tags]
    )
  end

  def list_links_for_user_filtered_by_tags(user_id, _), do: list_links_for_user(user_id)

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

  # Tag functions
  def list_tags_for_user(user_id) do
    Repo.all(from(t in Tag, where: t.user_id == ^user_id, order_by: t.name))
  end

  def create_tag(attrs) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  def find_or_create_tag(name, user_id) when is_binary(name) and name != "" do
    name = String.trim(name)

    case Repo.get_by(Tag, name: name, user_id: user_id) do
      nil -> create_tag(%{name: name, user_id: user_id})
      tag -> {:ok, tag}
    end
  end

  def add_tag_to_link(link, tag) do
    link
    |> Repo.preload(:tags)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, [tag | link.tags])
    |> Repo.update()
  end

  def remove_tag_from_link(link, tag) do
    link
    |> Repo.preload(:tags)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, Enum.reject(link.tags, &(&1.id == tag.id)))
    |> Repo.update()
  end

  def set_link_tags(link, tag_names) when is_list(tag_names) do
    user_id = link.user_id

    # Find or create all tags
    {:ok, tags} =
      tag_names
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.uniq()
      |> Enum.reduce({:ok, []}, fn name, {:ok, acc} ->
        case find_or_create_tag(name, user_id) do
          {:ok, tag} -> {:ok, [tag | acc]}
          error -> error
        end
      end)

    # Update link with new tags
    link
    |> Repo.preload(:tags)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, tags)
    |> Repo.update()
  end

  def get_link_with_tags(id) do
    Link
    |> Repo.get(id)
    |> Repo.preload(:tags)
  end

  @doc """
  Automatically generates and applies tags to a link using an LLM.
  """
  def auto_tag_link(link_id) when is_integer(link_id) do
    case get_link_with_tags(link_id) do
      nil -> {:error, :not_found}
      link -> auto_tag_link(link)
    end
  end

  def auto_tag_link(%Link{} = link) do
    with {:ok, tag_names} <- AutoTagger.generate_tags(link) do
      apply_tags_if_any(link, tag_names)
    end
  end

  defp apply_tags_if_any(link, []), do: {:ok, link}
  defp apply_tags_if_any(link, tag_names), do: set_link_tags(link, tag_names)

  @doc """
  Fetches metadata for a link and then automatically generates tags.
  """
  def fetch_metadata_and_auto_tag(link_id) do
    with {:ok, link} <- fetch_and_update_metadata(link_id) do
      auto_tag_link(link)
    end
  end
end
