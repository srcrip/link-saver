defmodule LinkSaver.Links.AutoTaggerTest do
  use LinkSaver.DataCase, async: true
  use Mimic

  alias LinkSaver.Links.AutoTagger
  alias LinkSaver.Links.Link

  setup do
    Mimic.copy(Instructor)
    Mimic.copy(System)
    :ok
  end

  setup :verify_on_exit!

  describe "generate_tags/1" do
    test "handles link with no content gracefully" do
      link = %Link{
        title: nil,
        description: nil,
        site_name: nil,
        raw_html: nil
      }

      assert {:ok, []} = AutoTagger.generate_tags(link)
    end

    test "successfully generates tags from link content" do
      link = %Link{
        title: "Getting Started with Elixir",
        description: "A comprehensive guide to learning Elixir programming language",
        site_name: "ElixirSchool",
        raw_html: """
        <html>
          <body>
            <article>
              <h1>Getting Started with Elixir</h1>
              <p>Elixir is a functional programming language built on the Erlang VM.</p>
              <p>It's designed for building scalable and maintainable applications.</p>
            </article>
          </body>
        </html>
        """
      }

      mock_response = %AutoTagger.TagSuggestion{
        tags: ["elixir", "programming", "functional", "erlang", "tutorial"],
        reasoning: "Tags based on programming language and educational content"
      }

      expect(System, :get_env, fn "GEMINI_API_KEY" -> "test-api-key" end)

      expect(Instructor, :chat_completion, fn _messages, _config ->
        {:ok, mock_response}
      end)

      result = AutoTagger.generate_tags(link)

      assert {:ok, tags} = result
      assert tags == ["elixir", "programming", "functional", "erlang", "tutorial"]
    end

    test "handles LLM API errors gracefully" do
      link = %Link{
        title: "Test Article",
        description: "Test description",
        site_name: "Test Site",
        raw_html: "<html><body>Test content</body></html>"
      }

      expect(System, :get_env, fn "GEMINI_API_KEY" -> "test-api-key" end)

      expect(Instructor, :chat_completion, fn _messages, _config ->
        {:error, "API rate limit exceeded"}
      end)

      result = AutoTagger.generate_tags(link)

      assert {:ok, []} = result
    end

    test "handles LLM API exceptions" do
      link = %Link{
        title: "Test Article",
        description: "Test description",
        site_name: "Test Site",
        raw_html: "<html><body>Test content</body></html>"
      }

      expect(System, :get_env, fn "GEMINI_API_KEY" -> "test-api-key" end)

      expect(Instructor, :chat_completion, fn _messages, _config ->
        raise "Network timeout"
      end)

      result = AutoTagger.generate_tags(link)

      assert {:ok, []} = result
    end

    test "cleans and validates returned tags" do
      link = %Link{
        title: "Web Development Guide",
        description: "Modern web development practices",
        site_name: "DevBlog",
        raw_html: "<html><body>Web development content</body></html>"
      }

      mock_response = %AutoTagger.TagSuggestion{
        tags: [
          " JavaScript ",
          "HTML",
          "CSS",
          "",
          "REACT",
          "react",
          "nodejs",
          "web-dev",
          "frontend",
          "backend",
          "database",
          "extra-tag"
        ],
        reasoning: "Tags for web development content"
      }

      expect(System, :get_env, fn "GEMINI_API_KEY" -> "test-api-key" end)

      expect(Instructor, :chat_completion, fn _messages, _config ->
        {:ok, mock_response}
      end)

      result = AutoTagger.generate_tags(link)

      assert {:ok, tags} = result
      # Should trim whitespace, convert to lowercase, remove duplicates, and limit to 10 tags
      expected_tags = [
        "javascript",
        "html",
        "css",
        "react",
        "nodejs",
        "web-dev",
        "frontend",
        "backend",
        "database",
        "extra-tag"
      ]

      assert tags == expected_tags
      assert length(tags) <= 10
    end

    test "handles missing API key configuration" do
      # This test simulates no API key being available
      # and should gracefully return empty tags
      link = %Link{
        title: "Test Article",
        description: "Test description",
        site_name: "Test Site",
        raw_html: "<html><body>Test content</body></html>"
      }

      # Mock System.get_env to return nil (no API key)
      expect(System, :get_env, fn "GEMINI_API_KEY" -> nil end)

      result = AutoTagger.generate_tags(link)
      assert {:ok, []} = result
    end

    test "handles invalid API key gracefully" do
      link = %Link{
        title: "Test Article",
        description: "Test description",
        site_name: "Test Site",
        raw_html: "<html><body>Test content</body></html>"
      }

      # Mock with an invalid API key that will cause LLM calls to fail
      expect(System, :get_env, fn "GEMINI_API_KEY" -> "invalid-key" end)

      expect(Instructor, :chat_completion, fn _messages, _config ->
        {:error, "Invalid API key"}
      end)

      result = AutoTagger.generate_tags(link)
      assert {:ok, []} = result
    end
  end

  describe "clean_and_validate_tags/1" do
    test "cleans and validates tag list" do
      # This is a private function, but we can test it through generate_tags if needed
      # For now, we'll test the overall behavior through the public API
      assert true
    end
  end
end
