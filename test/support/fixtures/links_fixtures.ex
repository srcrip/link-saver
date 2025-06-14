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
end
