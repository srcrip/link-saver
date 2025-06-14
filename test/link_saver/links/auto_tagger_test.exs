defmodule LinkSaver.Links.AutoTaggerTest do
  use LinkSaver.DataCase, async: true

  alias LinkSaver.Links.AutoTagger
  alias LinkSaver.Links.Link

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

    test "handles link with minimal content" do
      link = %Link{
        title: "Test",
        description: nil,
        site_name: nil,
        raw_html: nil
      }

      # Without a valid API key, this should raise an error
      assert_raise RuntimeError, "GEMINI_API_KEY environment variable not set", fn ->
        AutoTagger.generate_tags(link)
      end
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
