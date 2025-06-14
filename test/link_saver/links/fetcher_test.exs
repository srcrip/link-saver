defmodule LinkSaver.Links.FetcherTest do
  use ExUnit.Case, async: true

  alias LinkSaver.Links.Fetcher

  describe "extract_metadata/2" do
    test "extracts title from title tag" do
      html = """
      <html>
        <head>
          <title>Test Page Title</title>
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.title == "Test Page Title"
    end

    test "extracts OpenGraph metadata" do
      html = """
      <html>
        <head>
          <meta property="og:title" content="OG Title" />
          <meta property="og:description" content="OG Description" />
          <meta property="og:image" content="https://example.com/image.jpg" />
          <meta property="og:site_name" content="OG Site" />
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.title == "OG Title"
      assert metadata.description == "OG Description"
      assert metadata.image_url == "https://example.com/image.jpg"
      assert metadata.site_name == "OG Site"
    end

    test "extracts Twitter Card metadata" do
      html = """
      <html>
        <head>
          <meta name="twitter:title" content="Twitter Title" />
          <meta name="twitter:description" content="Twitter Description" />
          <meta name="twitter:image" content="https://example.com/twitter.jpg" />
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.title == "Twitter Title"
      assert metadata.description == "Twitter Description"
      assert metadata.image_url == "https://example.com/twitter.jpg"
    end

    test "extracts meta description" do
      html = """
      <html>
        <head>
          <meta name="description" content="Meta description content" />
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.description == "Meta description content"
    end

    test "prefers OpenGraph over Twitter Card" do
      html = """
      <html>
        <head>
          <meta property="og:title" content="OG Title" />
          <meta name="twitter:title" content="Twitter Title" />
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.title == "OG Title"
    end

    test "prefers OpenGraph over title tag" do
      html = """
      <html>
        <head>
          <title>HTML Title</title>
          <meta property="og:title" content="OG Title" />
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.title == "OG Title"
    end

    test "extracts site name from URL when not in meta" do
      html = """
      <html>
        <head><title>Test</title></head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://github.com/user/repo")

      assert metadata.site_name == "Github"
    end

    test "resolves relative image URLs" do
      html = """
      <html>
        <head>
          <meta property="og:image" content="/image.jpg" />
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.image_url == "https://example.com/image.jpg"
    end

    test "handles malformed HTML gracefully" do
      html = "<html><title>Test</title><body>Unclosed tags"

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.title == "Test"
      assert metadata.site_name == "Example"
      assert is_struct(metadata.fetched_at, DateTime)
    end

    test "includes fetched_at timestamp" do
      html = "<html><head><title>Test</title></head></html>"

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert is_struct(metadata.fetched_at, DateTime)
    end

    test "extracts favicon from link tags" do
      html = """
      <html>
        <head>
          <link rel="icon" href="/favicon.ico" />
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.favicon_url == "https://example.com/favicon.ico"
    end

    test "prefers apple-touch-icon over regular icon" do
      html = """
      <html>
        <head>
          <link rel="apple-touch-icon" href="/apple-icon.png" />
          <link rel="icon" href="/favicon.ico" />
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.favicon_url == "https://example.com/apple-icon.png"
    end

    test "falls back to /favicon.ico when no icon links found" do
      html = """
      <html>
        <head><title>Test</title></head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert metadata.favicon_url == "https://example.com/favicon.ico"
    end

    test "truncates long descriptions" do
      long_description = String.duplicate("a", 350)

      html = """
      <html>
        <head>
          <meta name="description" content="#{long_description}" />
        </head>
        <body>Content</body>
      </html>
      """

      metadata = Fetcher.extract_metadata(html, "https://example.com")

      assert String.length(metadata.description) == 300
      assert String.ends_with?(metadata.description, "...")
    end
  end

  describe "fetch_metadata/1" do
    # Note: These are integration tests that would require mocking HTTP requests
    # In a real test suite, you'd want to mock Req.get/2 to return predictable responses

    test "returns error for invalid URLs" do
      result = Fetcher.fetch_metadata("not-a-url")

      assert {:error, _reason} = result
    end
  end
end
