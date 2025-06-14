defmodule LinkSaver.Links.Fetcher do
  @moduledoc """
  Handles fetching URLs and extracting metadata from web pages.
  """

  require Logger

  @doc """
  Fetches a URL and extracts metadata from the HTML.
  Returns a map with extracted metadata or an error.
  """
  def fetch_metadata(url) do
    Logger.info("Fetching metadata for URL: #{url}")

    case fetch_html(url) do
      {:ok, html} ->
        metadata = extract_metadata(html, url)
        {:ok, Map.put(metadata, :raw_html, html)}

      {:error, reason} ->
        Logger.warning("Failed to fetch URL #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def fetch_html(url) do
    case Req.get(url,
           max_redirects: 5,
           receive_timeout: 10_000,
           headers: [
             {"user-agent", "curl/8.4.0"}
           ]
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    exception ->
      {:error, Exception.message(exception)}
  end

  def extract_metadata(html, url) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        %{
          title: extract_title(document),
          description: extract_description(document),
          image_url: extract_image_url(document, url),
          site_name: extract_site_name(document, url),
          favicon_url: extract_favicon_url(document, url),
          fetched_at: DateTime.utc_now()
        }

      {:error, _reason} ->
        # If HTML parsing fails, return basic metadata
        %{
          title: extract_title_fallback(html),
          description: nil,
          image_url: nil,
          site_name: extract_site_name_from_url(url),
          favicon_url: extract_favicon_url_fallback(url),
          fetched_at: DateTime.utc_now()
        }
    end
  end

  defp extract_title(document) do
    # Try multiple sources for title in order of preference
    title =
      extract_meta_property(document, "og:title") ||
        extract_meta_name(document, "twitter:title") ||
        extract_title_tag(document)

    title && String.trim(title)
  end

  defp extract_description(document) do
    description =
      extract_meta_property(document, "og:description") ||
        extract_meta_name(document, "twitter:description") ||
        extract_meta_name(document, "description")

    description && description |> String.trim() |> truncate_description()
  end

  defp extract_image_url(document, base_url) do
    image_url =
      extract_meta_property(document, "og:image") ||
        extract_meta_name(document, "twitter:image")

    case image_url do
      nil -> nil
      url -> resolve_url(url, base_url)
    end
  end

  defp extract_site_name(document, url) do
    site_name =
      extract_meta_property(document, "og:site_name") ||
        extract_site_name_from_url(url)

    site_name && String.trim(site_name)
  end

  defp extract_favicon_url(document, base_url) do
    # Try multiple sources for favicon in order of preference
    # Modern high-resolution favicons
    # Fallback to standard /favicon.ico
    favicon_url =
      extract_link_rel(document, "apple-touch-icon") ||
        extract_link_rel(document, "icon") ||
        extract_link_rel(document, "shortcut icon") ||
        "/favicon.ico"

    case favicon_url do
      nil -> nil
      url -> resolve_url(url, base_url)
    end
  end

  # Helper functions for extracting specific meta tags
  defp extract_meta_property(document, property) do
    document
    |> Floki.find("meta[property='#{property}']")
    |> Floki.attribute("content")
    |> List.first()
  end

  defp extract_meta_name(document, name) do
    document
    |> Floki.find("meta[name='#{name}']")
    |> Floki.attribute("content")
    |> List.first()
  end

  defp extract_link_rel(document, rel) do
    document
    |> Floki.find("link[rel*='#{rel}']")
    |> Floki.attribute("href")
    |> List.first()
  end

  defp extract_title_tag(document) do
    document
    |> Floki.find("title")
    |> Floki.text()
    |> case do
      "" -> nil
      title -> title
    end
  end

  defp extract_title_fallback(html) do
    case Regex.run(~r/<title[^>]*>([^<]+)<\/title>/i, html) do
      [_, title] -> String.trim(title)
      _ -> nil
    end
  end

  defp extract_site_name_from_url(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) ->
        host
        |> String.replace(~r/^www\./, "")
        |> String.split(".")
        |> hd()
        |> String.capitalize()

      _ ->
        nil
    end
  end

  defp resolve_url(url, base_url) do
    case URI.parse(url) do
      %URI{scheme: nil} ->
        base_uri = URI.parse(base_url)
        "#{base_uri.scheme}://#{base_uri.host}#{url}"

      _ ->
        url
    end
  end

  defp truncate_description(description) when is_binary(description) do
    if String.length(description) > 300 do
      String.slice(description, 0, 297) <> "..."
    else
      description
    end
  end

  defp truncate_description(nil), do: nil

  defp extract_favicon_url_fallback(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when not is_nil(scheme) and not is_nil(host) ->
        "#{scheme}://#{host}/favicon.ico"

      _ ->
        nil
    end
  end
end
