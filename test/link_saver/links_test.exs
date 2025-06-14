defmodule LinkSaver.LinksTest do
  use LinkSaver.DataCase

  import LinkSaver.LinksFixtures
  import LinkSaver.UsersFixtures

  alias LinkSaver.Links
  alias LinkSaver.Links.Link

  describe "links metadata" do
    test "update_link_metadata/2 updates metadata fields" do
      user = user_fixture()
      link = link_fixture(user)

      metadata = %{
        title: "Updated Title",
        description: "Updated Description",
        site_name: "Updated Site",
        image_url: "https://example.com/updated.jpg",
        favicon_url: "https://example.com/favicon.ico",
        raw_html: "<html>Updated</html>",
        fetched_at: DateTime.utc_now()
      }

      assert {:ok, updated_link} = Links.update_link_metadata(link, metadata)
      assert updated_link.title == "Updated Title"
      assert updated_link.description == "Updated Description"
      assert updated_link.site_name == "Updated Site"
      assert updated_link.image_url == "https://example.com/updated.jpg"
      assert updated_link.favicon_url == "https://example.com/favicon.ico"
      assert updated_link.raw_html == "<html>Updated</html>"
      assert updated_link.fetched_at
    end

    test "update_link_metadata/2 validates field lengths" do
      user = user_fixture()
      link = link_fixture(user)

      metadata = %{
        # Too long
        title: String.duplicate("a", 501),
        # Too long
        site_name: String.duplicate("b", 201),
        # Too long
        image_url: String.duplicate("c", 1001),
        # Too long
        favicon_url: String.duplicate("d", 1001)
      }

      assert {:error, changeset} = Links.update_link_metadata(link, metadata)
      assert "should be at most 500 character(s)" in errors_on(changeset).title
      assert "should be at most 200 character(s)" in errors_on(changeset).site_name
      assert "should be at most 1000 character(s)" in errors_on(changeset).image_url
      assert "should be at most 1000 character(s)" in errors_on(changeset).favicon_url
    end

    test "update_link_metadata/2 handles fetch errors" do
      user = user_fixture()
      link = link_fixture(user)

      metadata = %{
        fetch_error: "Connection timeout",
        fetched_at: DateTime.utc_now()
      }

      assert {:ok, updated_link} = Links.update_link_metadata(link, metadata)
      assert updated_link.fetch_error == "Connection timeout"
      assert updated_link.fetched_at
    end
  end

  describe "metadata_changeset/2" do
    test "casts metadata fields" do
      link = %Link{}

      attrs = %{
        title: "Test Title",
        description: "Test Description",
        site_name: "Test Site",
        image_url: "https://example.com/image.jpg",
        favicon_url: "https://example.com/favicon.ico",
        raw_html: "<html>Test</html>",
        fetched_at: DateTime.utc_now(),
        fetch_error: nil
      }

      changeset = Link.metadata_changeset(link, attrs)

      assert changeset.valid?
      assert get_change(changeset, :title) == "Test Title"
      assert get_change(changeset, :description) == "Test Description"
      assert get_change(changeset, :site_name) == "Test Site"
      assert get_change(changeset, :image_url) == "https://example.com/image.jpg"
      assert get_change(changeset, :favicon_url) == "https://example.com/favicon.ico"
      assert get_change(changeset, :raw_html) == "<html>Test</html>"
      assert get_change(changeset, :fetched_at)
    end

    test "validates title length" do
      link = %Link{}
      attrs = %{title: String.duplicate("a", 501)}

      changeset = Link.metadata_changeset(link, attrs)

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).title
    end

    test "validates site_name length" do
      link = %Link{}
      attrs = %{site_name: String.duplicate("a", 201)}

      changeset = Link.metadata_changeset(link, attrs)

      refute changeset.valid?
      assert "should be at most 200 character(s)" in errors_on(changeset).site_name
    end

    test "validates image_url length" do
      link = %Link{}
      attrs = %{image_url: String.duplicate("a", 1001)}

      changeset = Link.metadata_changeset(link, attrs)

      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).image_url
    end

    test "validates favicon_url length" do
      link = %Link{}
      attrs = %{favicon_url: String.duplicate("a", 1001)}

      changeset = Link.metadata_changeset(link, attrs)

      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).favicon_url
    end
  end
end
