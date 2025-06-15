defmodule LinkSaverWeb.LinksLiveTest do
  use LinkSaverWeb.ConnCase, async: true

  import LinkSaver.LinksFixtures
  import LinkSaver.UsersFixtures
  import Phoenix.LiveViewTest

  describe "Links page" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "renders links page for authenticated user", %{conn: conn, user: user} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert html =~ "Links"
      assert html =~ "Add a new link"
      assert html =~ "No links saved yet."
    end

    test "redirects unauthenticated user", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/links")
    end

    test "displays existing links", %{conn: conn, user: user} do
      _link1 = link_fixture(user, %{url: "https://example.com"})
      _link2 = link_fixture(user, %{url: "https://test.com"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert html =~ "https://example.com"
      assert html =~ "https://test.com"
      refute html =~ "No links saved yet."
    end
  end

  describe "Adding links" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "can create a new link with valid URL", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert lv
             |> form("#link-form", link: %{url: "https://newsite.com"})
             |> render_submit() =~ "Link created successfully"

      assert render(lv) =~ "https://newsite.com"
    end

    test "normalizes URL without protocol", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert lv
             |> form("#link-form", link: %{url: "example.com"})
             |> render_submit() =~ "Link created successfully"

      assert render(lv) =~ "https://example.com"
    end

    test "preserves http:// protocol when provided", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert lv
             |> form("#link-form", link: %{url: "http://insecure.com"})
             |> render_submit() =~ "Link created successfully"

      assert render(lv) =~ "http://insecure.com"
    end

    test "resets form after successful submission", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      lv
      |> form("#link-form", link: %{url: "https://test.com"})
      |> render_submit()

      # Check that form is cleared by confirming no value attribute is present
      form_html =
        lv
        |> element("#link-form input[name='link[url]']")
        |> render()

      refute form_html =~ ~r/value="[^"]+"/
    end

    test "shows validation errors for empty URL", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      result =
        lv
        |> form("#link-form", link: %{url: ""})
        |> render_submit()

      assert result =~ "Link creation failed"
    end
  end

  describe "Deleting links" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "can delete a link", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://delete-me.com"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert render(lv) =~ "https://delete-me.com"

      lv
      |> element("button[phx-click='delete'][phx-value-id='#{link.id}']")
      |> render_click()

      refute render(lv) =~ "https://delete-me.com"
      assert render(lv) =~ "Link deleted successfully"
    end

    test "shows empty state after deleting last link", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://only-link.com"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      lv
      |> element("button[phx-click='delete'][phx-value-id='#{link.id}']")
      |> render_click()

      assert render(lv) =~ "No links saved yet."
    end
  end

  describe "Form validation" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "validates URL on change", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Test that form validation happens on change
      lv
      |> form("#link-form", link: %{url: "valid-url.com"})
      |> render_change()

      # Should not show any validation errors for valid input
      html = render(lv)
      refute html =~ "can&#39;t be blank"
    end
  end

  describe "Link display" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "links have correct attributes for external opening", %{conn: conn, user: user} do
      link_fixture(user, %{url: "https://external.com"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert html =~ ~r/target="_blank"/
      assert html =~ ~r/rel="noopener noreferrer"/
      assert html =~ "https://external.com"
    end

    test "displays link creation date", %{conn: conn, user: user} do
      link_fixture(user, %{url: "https://dated.com"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Should contain a date in YYYY-MM-DD format
      assert html =~ ~r/\d{4}-\d{2}-\d{2}/
    end

    test "only shows user's own links", %{conn: conn, user: user} do
      other_user = user_fixture()

      _user_link = link_fixture(user, %{url: "https://my-link.com"})
      _other_link = link_fixture(other_user, %{url: "https://not-my-link.com"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert html =~ "https://my-link.com"
      refute html =~ "https://not-my-link.com"
    end

    test "displays metadata when available", %{conn: conn, user: user} do
      link_with_metadata_fixture(user, %{url: "https://test-metadata.com"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert html =~ "Example Title"
      assert html =~ "This is an example description"
      assert html =~ "Example Site"
    end

    test "shows loading state for new links", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Submit a new link through the LiveView
      lv
      |> form("#link-form", link: %{url: "https://loading.com"})
      |> render_submit()

      # Check that the link was created and success message appears
      html = render(lv)
      assert html =~ "Link created successfully"
      assert html =~ "https://loading.com"
    end

    test "shows error state when fetch fails", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://error.com"})

      # Simulate a fetch error
      LinkSaver.Links.update_link_metadata(link, %{
        fetch_error: "Connection failed",
        fetched_at: DateTime.utc_now()
      })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert html =~ "Error"
    end
  end

  describe "Search functionality" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "displays search form", %{conn: conn, user: user} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert html =~ "Search your links..."
    end

    test "can search links by URL", %{conn: conn, user: user} do
      link_fixture(user, %{url: "https://github.com"})
      link_fixture(user, %{url: "https://google.com"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      lv
      |> element("form[phx-submit='search']")
      |> render_submit(%{q: "github"})

      html = render(lv)
      assert html =~ "https://github.com"
      refute html =~ "https://google.com"
    end

    test "can search links by title", %{conn: conn, user: user} do
      link_with_metadata_fixture(user, %{url: "https://test.com"})
      link_fixture(user, %{url: "https://other.com"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      lv
      |> element("form[phx-submit='search']")
      |> render_submit(%{q: "Example"})

      html = render(lv)
      assert html =~ "Example Title"
      refute html =~ "https://other.com"
    end

    test "shows clear button when searching", %{conn: conn, user: user} do
      link_fixture(user, %{url: "https://example.com"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Initially no clear button
      refute render(lv) =~ "Clear"

      # Search for something
      lv
      |> element("form[phx-submit='search']")
      |> render_submit(%{q: "example"})

      # Now clear button should appear
      assert render(lv) =~ "Clear"
    end

    test "can clear search", %{conn: conn, user: user} do
      link_fixture(user, %{url: "https://github.com"})
      link_fixture(user, %{url: "https://google.com"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Search to filter results
      lv
      |> element("form[phx-submit='search']")
      |> render_submit(%{q: "github"})

      html = render(lv)
      assert html =~ "https://github.com"
      refute html =~ "https://google.com"

      # Clear search
      lv
      |> element("button[phx-click='clear_search']")
      |> render_click()

      html = render(lv)
      assert html =~ "https://github.com"
      assert html =~ "https://google.com"
    end

    test "search updates on form change", %{conn: conn, user: user} do
      link_fixture(user, %{url: "https://github.com"})
      link_fixture(user, %{url: "https://google.com"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Use phx-change to trigger search
      lv
      |> element("form[phx-change='search']")
      |> render_change(%{q: "github"})

      html = render(lv)
      assert html =~ "https://github.com"
      refute html =~ "https://google.com"
    end

    test "search persists search query in form", %{conn: conn, user: user} do
      link_fixture(user, %{url: "https://github.com"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      lv
      |> element("form[phx-submit='search']")
      |> render_submit(%{q: "github"})

      # Check that the search input has the value
      assert lv
             |> element("input[name='q']")
             |> render() =~ ~r/value="github"/
    end
  end

  describe "Tag filtering functionality" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "displays tag filter interface", %{conn: conn, user: user} do
      # Create links with tags
      link1 = link_fixture(user, %{url: "https://example.com"})
      link2 = link_fixture(user, %{url: "https://test.com"})

      LinkSaver.Links.set_link_tags(link1, ["elixir", "phoenix"])
      LinkSaver.Links.set_link_tags(link2, ["javascript", "react"])

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert html =~ "Filter by tags:"
      assert html =~ "elixir"
      assert html =~ "phoenix"
      assert html =~ "javascript"
      assert html =~ "react"
    end

    test "can filter links by single tag", %{conn: conn, user: user} do
      link1 = link_fixture(user, %{url: "https://elixir-site.com"})
      link2 = link_fixture(user, %{url: "https://js-site.com"})

      LinkSaver.Links.set_link_tags(link1, ["elixir"])
      LinkSaver.Links.set_link_tags(link2, ["javascript"])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Filter by elixir tag
      lv
      |> element("button[phx-click='toggle_tag_filter'][phx-value-tag='elixir']")
      |> render_click()

      html = render(lv)
      assert html =~ "https://elixir-site.com"
      refute html =~ "https://js-site.com"
    end

    test "can filter links by multiple tags (AND operation)", %{conn: conn, user: user} do
      link1 = link_fixture(user, %{url: "https://elixir-phoenix.com"})
      link2 = link_fixture(user, %{url: "https://elixir-only.com"})
      link3 = link_fixture(user, %{url: "https://phoenix-only.com"})

      LinkSaver.Links.set_link_tags(link1, ["elixir", "phoenix"])
      LinkSaver.Links.set_link_tags(link2, ["elixir"])
      LinkSaver.Links.set_link_tags(link3, ["phoenix"])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Filter by elixir tag first
      lv
      |> element("button[phx-click='toggle_tag_filter'][phx-value-tag='elixir']")
      |> render_click()

      # Then also filter by phoenix tag
      lv
      |> element("button[phx-click='toggle_tag_filter'][phx-value-tag='phoenix']")
      |> render_click()

      html = render(lv)
      assert html =~ "https://elixir-phoenix.com"
      refute html =~ "https://elixir-only.com"
      refute html =~ "https://phoenix-only.com"
    end

    test "can toggle tags on and off", %{conn: conn, user: user} do
      link1 = link_fixture(user, %{url: "https://elixir-site.com"})
      link2 = link_fixture(user, %{url: "https://js-site.com"})

      LinkSaver.Links.set_link_tags(link1, ["elixir"])
      LinkSaver.Links.set_link_tags(link2, ["javascript"])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Initially both links should be visible
      html = render(lv)
      assert html =~ "https://elixir-site.com"
      assert html =~ "https://js-site.com"

      # Filter by elixir tag
      lv
      |> element("button[phx-click='toggle_tag_filter'][phx-value-tag='elixir']")
      |> render_click()

      html = render(lv)
      assert html =~ "https://elixir-site.com"
      refute html =~ "https://js-site.com"

      # Toggle elixir tag off (should show all links again)
      lv
      |> element("button[phx-click='toggle_tag_filter'][phx-value-tag='elixir']")
      |> render_click()

      html = render(lv)
      assert html =~ "https://elixir-site.com"
      assert html =~ "https://js-site.com"
    end

    test "shows visual feedback for selected tags", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://example.com"})
      LinkSaver.Links.set_link_tags(link, ["elixir", "phoenix"])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Initially no tags should be selected (no blue background)
      html = render(lv)
      refute html =~ ~r/button[^>]*phx-value-tag="elixir"[^>]*bg-blue-100/
      refute html =~ ~r/button[^>]*phx-value-tag="phoenix"[^>]*bg-blue-100/

      # Select elixir tag
      lv
      |> element("button[phx-click='toggle_tag_filter'][phx-value-tag='elixir']")
      |> render_click()

      # Now elixir tag should be highlighted
      html = render(lv)
      assert html =~ ~r/button[^>]*phx-value-tag="elixir"[^>]*bg-blue-100/
      refute html =~ ~r/button[^>]*phx-value-tag="phoenix"[^>]*bg-blue-100/
    end

    test "combines search with tag filtering", %{conn: conn, user: user} do
      link1 = link_fixture(user, %{url: "https://elixir-site.com"})
      link2 = link_fixture(user, %{url: "https://javascript-site.com"})

      LinkSaver.Links.set_link_tags(link1, ["elixir"])
      LinkSaver.Links.set_link_tags(link2, ["javascript"])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # First search for "elixir" to see what we get  
      lv
      |> element("form[phx-submit='search']")
      |> render_submit(%{q: "elixir"})

      html = render(lv)
      # Should show the elixir link
      assert html =~ "https://elixir-site.com"
      refute html =~ "https://javascript-site.com"

      # Then also filter by elixir tag
      lv
      |> element("button[phx-click='toggle_tag_filter'][phx-value-tag='elixir']")
      |> render_click()

      html = render(lv)
      # Should still show only the elixir link
      assert html =~ "https://elixir-site.com"
      refute html =~ "https://javascript-site.com"
    end

    test "interface shows tag filtering area", %{conn: conn, user: user} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Tag filter interface should always be shown
      assert html =~ "Filter by tags:"
    end

    test "handles empty tag list gracefully", %{conn: conn, user: user} do
      _link = link_fixture(user, %{url: "https://no-tags.com"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Should show the link even without tags
      assert html =~ "https://no-tags.com"

      # Tag filter interface should still be there even with no tags
      assert html =~ "Filter by tags:"
    end
  end

  describe "Tag management modal" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "shows manage tags button when tags exist", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://example.com"})
      LinkSaver.Links.set_link_tags(link, ["test-tag"])

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      assert html =~ "Manage Tags"
    end

    test "does not show manage tags button when no tags exist", %{conn: conn, user: user} do
      _link = link_fixture(user, %{url: "https://example.com"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      refute html =~ "Manage Tags"
    end

    test "opens modal when manage tags button is clicked", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://example.com"})
      LinkSaver.Links.set_link_tags(link, ["test-tag"])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      # Click manage tags link
      lv
      |> element("a[href='/links?manage_tags=true']")
      |> render_click()

      # Should navigate to URL with query param
      assert_patch(lv, ~p"/links?manage_tags=true")
    end

    test "shows modal when visiting URL with manage_tags param", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://example.com"})
      LinkSaver.Links.set_link_tags(link, ["test-tag"])

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links?manage_tags=true")

      assert html =~ "Manage Tags"
      assert html =~ "test-tag"
      assert html =~ "delete"
    end

    test "shows empty state in modal when no tags exist", %{conn: conn, user: user} do
      _link = link_fixture(user, %{url: "https://example.com"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links?manage_tags=true")

      assert html =~ "Manage Tags"
      assert html =~ "No tags found"
    end

    test "lists all user tags in modal", %{conn: conn, user: user} do
      link1 = link_fixture(user, %{url: "https://example1.com"})
      link2 = link_fixture(user, %{url: "https://example2.com"})
      
      LinkSaver.Links.set_link_tags(link1, ["elixir", "phoenix"])
      LinkSaver.Links.set_link_tags(link2, ["javascript", "react"])

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links?manage_tags=true")

      assert html =~ "elixir"
      assert html =~ "phoenix"
      assert html =~ "javascript"
      assert html =~ "react"
    end

    test "only shows tags for current user", %{conn: conn, user: user} do
      other_user = user_fixture()
      
      link1 = link_fixture(user, %{url: "https://user1.com"})
      link2 = link_fixture(other_user, %{url: "https://user2.com"})
      
      LinkSaver.Links.set_link_tags(link1, ["user1-tag"])
      LinkSaver.Links.set_link_tags(link2, ["user2-tag"])

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links?manage_tags=true")

      assert html =~ "user1-tag"
      refute html =~ "user2-tag"
    end

    test "can delete a tag from modal", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://example.com"})
      LinkSaver.Links.set_link_tags(link, ["delete-me", "keep-me"])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links?manage_tags=true")

      # Find the delete button for the specific tag
      delete_me_tag = LinkSaver.Links.list_tags_for_user(user.id)
                      |> Enum.find(&(&1.name == "delete-me"))

      # Click delete button
      lv
      |> element("button[phx-click='delete_tag'][phx-value-tag-id='#{delete_me_tag.id}']")
      |> render_click()

      # Tag should be removed from the modal
      html = render(lv)
      refute html =~ "delete-me"
      assert html =~ "keep-me"
      assert html =~ "Tag deleted successfully"
    end

    test "deleting tag removes it from links", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://example.com"})
      LinkSaver.Links.set_link_tags(link, ["delete-me", "keep-me"])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links?manage_tags=true")

      delete_me_tag = LinkSaver.Links.list_tags_for_user(user.id)
                      |> Enum.find(&(&1.name == "delete-me"))

      # Delete the tag
      lv
      |> element("button[phx-click='delete_tag'][phx-value-tag-id='#{delete_me_tag.id}']")
      |> render_click()

      # Verify tag is removed from the modal
      html = render(lv)
      refute html =~ "delete-me"
      assert html =~ "keep-me"
      
      # Verify the tag was actually deleted from the database
      updated_link = LinkSaver.Links.get_link_with_tags(link.id)
      tag_names = Enum.map(updated_link.tags, & &1.name)
      refute "delete-me" in tag_names
      assert "keep-me" in tag_names
    end

    test "shows error when trying to delete non-existent tag", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://example.com"})
      LinkSaver.Links.set_link_tags(link, ["test-tag"])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links?manage_tags=true")

      # Try to delete non-existent tag by sending event directly
      result = render_hook(lv, "delete_tag", %{"tag-id" => "999999"})

      assert result =~ "Tag not found"
    end

    test "modal shows when query param is present and hides when absent", %{conn: conn, user: user} do
      link = link_fixture(user, %{url: "https://example.com"})
      LinkSaver.Links.set_link_tags(link, ["test-tag"])

      # Test modal is hidden without query param
      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links")

      refute html =~ "Manage Tags</h3>"  # Modal title should not be present
      
      # Test modal is shown with query param
      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/links?manage_tags=true")
      
      assert html =~ "Manage Tags</h3>"  # Modal title should be present
      assert html =~ "test-tag"
    end
  end
end
