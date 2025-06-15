defmodule LinkSaver.Links.AutoTagger do
  @moduledoc """
  Automatically generates tags for links using an LLM.
  """

  # Constants
  @max_content_length 4000
  @max_html_text_length 2000
  @max_tags 10
  @tag_count_range 3..7

  defmodule TagSuggestion do
    @moduledoc false
    use Ecto.Schema
    use Instructor.Validator

    @doc """
    Analyze web content and suggest 3-7 relevant tags for categorization.
    Tags should be concise, searchable terms focusing on topics, technologies, or themes.
    """

    @primary_key false
    embedded_schema do
      field(:tags, {:array, :string})
      field(:reasoning, :string)
    end
  end

  @doc """
  Generates tags for a link based on its content using Gemini.
  """
  def generate_tags(link) do
    with content when content != "" <- build_content_for_analysis(link),
         prompt = build_prompt(content),
         {:ok, %{tags: tags}} <- call_llm(prompt) do
      {:ok, clean_and_validate_tags(tags)}
    else
      "" -> {:ok, []}
      {:error, _reason} -> {:ok, []}
    end
  end

  defp build_content_for_analysis(link) do
    [link.title, link.description, link.site_name, extract_text_from_html(link.raw_html)]
    |> Enum.filter(&(&1 && String.trim(&1) != ""))
    |> Enum.join(" ")
    |> String.slice(0, @max_content_length)
  end

  defp extract_text_from_html(nil), do: ""

  defp extract_text_from_html(html) when is_binary(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        document
        |> find_main_content()
        |> Floki.text(sep: " ")
        |> String.slice(0, @max_html_text_length)

      _ ->
        ""
    end
  end

  defp find_main_content(document) do
    case Floki.find(document, "main, article, .content, .post, .entry") do
      [] -> Floki.find(document, "body")
      content -> content
    end
  end

  defp build_prompt(content) do
    """
    Analyze the following web content and suggest #{Enum.min(@tag_count_range)}-#{Enum.max(@tag_count_range)} relevant tags that would help categorize and find this content later.

    Guidelines:
    - Tags should be descriptive, specific, and useful for organization
    - Use common, searchable terms
    - Prefer lowercase
    - Keep tags concise (1-3 words each)
    - Focus on topics, technologies, concepts, or themes
    - Avoid overly generic tags like "article" or "website"

    Content to analyze:
    #{content}

    Please provide your tag suggestions and a brief reasoning for your choices.
    """
  end

  defp call_llm(prompt) do
    case get_api_key() do
      nil ->
        {:error, "API key not configured"}

      api_key ->
        config = [adapter: Instructor.Adapters.Gemini, api_key: api_key]

        Instructor.chat_completion(
          [
            model: "gemini-2.0-flash-exp",
            mode: :json_schema,
            response_model: TagSuggestion,
            messages: [%{role: "user", content: prompt}]
          ],
          config
        )
    end
  rescue
    error -> {:error, "LLM call failed: #{Exception.message(error)}"}
  end

  defp get_api_key do
    System.get_env("GEMINI_API_KEY") ||
      Application.get_env(:link_saver, :gemini_api_key)
  end

  defp clean_and_validate_tags(tags) when is_list(tags) do
    tags
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
    |> Enum.take(@max_tags)
  end
end
