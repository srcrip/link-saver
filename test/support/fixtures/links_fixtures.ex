defmodule LinkSaver.LinksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LinkSaver.Links` context.
  """

  def valid_link_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      url: "https://example.com"
    })
  end

  def link_fixture(user, attrs \\ %{}) do
    attrs =
      attrs
      |> valid_link_attributes()
      |> Map.put(:user_id, user.id)

    {:ok, link} = LinkSaver.Links.create_link(attrs)
    link
  end

  def link_with_metadata_fixture(user, attrs \\ %{}) do
    link = link_fixture(user, attrs)
    
    metadata = %{
      title: "Example Title",
      description: "This is an example description of the webpage.",
      site_name: "Example Site",
      image_url: "https://example.com/image.jpg",
      favicon_url: "https://example.com/favicon.ico",
      raw_html: "<html><head><title>Example Title</title></head><body>Content</body></html>",
      fetched_at: DateTime.utc_now()
    }
    
    {:ok, link_with_metadata} = LinkSaver.Links.update_link_metadata(link, metadata)
    link_with_metadata
  end
end
