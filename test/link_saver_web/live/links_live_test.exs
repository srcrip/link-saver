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
  end
end
