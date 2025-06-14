defmodule LinkSaverWeb.LinksLive do
  @moduledoc false
  use LinkSaverWeb, :live_view

  alias LinkSaver.Links
  alias LinkSaver.Links.Link

  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-lg font-medium mb-4">Links</h1>

      <div class="bg-zinc-50 border border-zinc-200 rounded-lg p-4 mb-6">
        <.form for={@form} phx-submit="submit" phx-change="validate" id="link-form">
          <div class="flex gap-3 items-end">
            <div class="flex-1">
              <.input
                field={@form[:url]}
                autocomplete="off"
                placeholder="https://example.com"
                required
                label="Add a new link"
              />
            </div>
            <.button type="submit">
              Add Link
            </.button>
          </div>
        </.form>
      </div>

      <div class="mb-6">
        <form phx-submit="search" phx-change="search" class="flex gap-3">
          <div class="flex-1">
            <input
              type="text"
              name="q"
              value={@search_query}
              placeholder="Search your links..."
              class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>
          <%= if @search_query && @search_query != "" do %>
            <.button type="button" phx-click="clear_search">
              Clear
            </.button>
          <% end %>
        </form>
      </div>

      <%= if @links == [] do %>
        <p class="text-gray-500 text-sm">No links saved yet.</p>
      <% else %>
        <div class="space-y-4">
          <div
            :for={link <- @links}
            class="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow"
          >
            <div class="flex items-start justify-between">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-2">
                  <%= if link.favicon_url do %>
                    <img
                      src={link.favicon_url}
                      alt="Favicon"
                      class="w-4 h-4 flex-shrink-0"
                      loading="lazy"
                      onerror="this.style.display='none'"
                    />
                  <% else %>
                    <div class="w-4 h-4 bg-gray-300 rounded-sm flex-shrink-0"></div>
                  <% end %>

                  <%= if link.title do %>
                    <h3 class="text-sm font-medium text-gray-900 truncate">
                      <a
                        href={link.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        class="hover:text-blue-600"
                      >
                        {link.title}
                      </a>
                    </h3>
                  <% else %>
                    <a
                      href={link.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-sm font-medium text-blue-600 hover:underline truncate block"
                    >
                      {link.url}
                    </a>
                  <% end %>

                  <%= if is_nil(link.fetched_at) and is_nil(link.fetch_error) do %>
                    <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded-full">
                      Loading...
                    </span>
                  <% end %>

                  <%= if link.fetch_error do %>
                    <span class="text-xs bg-red-100 text-red-800 px-2 py-1 rounded-full">
                      Error
                    </span>
                  <% end %>
                </div>

                <%= if link.description do %>
                  <p class="text-sm text-gray-600 mb-2">
                    {link.description}
                  </p>
                <% end %>

                <div class="flex items-center gap-4 text-xs text-gray-500">
                  <%= if link.site_name do %>
                    <span>{link.site_name}</span>
                  <% end %>
                  <span>{Calendar.strftime(link.inserted_at, "%Y-%m-%d")}</span>
                  <%= if link.fetched_at do %>
                    <span>Updated {Calendar.strftime(link.fetched_at, "%Y-%m-%d")}</span>
                  <% end %>
                </div>

                <div class="mt-2">
                  <a
                    href={link.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-xs text-blue-600 hover:underline truncate block"
                  >
                    {link.url}
                  </a>
                </div>

                <div class="mt-3">
                  <div class="flex flex-wrap gap-1 mb-2">
                    <span
                      :for={tag <- link.tags}
                      class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
                    >
                      {tag.name}
                    </span>
                  </div>

                  <form phx-submit="save_tags" phx-value-link-id={link.id} class="flex gap-2">
                    <input
                      type="text"
                      name="tags"
                      id={"tag-input-#{link.id}"}
                      value={Enum.map_join(link.tags, ", ", & &1.name)}
                      placeholder="Add tags separated by commas..."
                      class="flex-1 text-xs border-gray-300 rounded-md focus:border-blue-500 focus:ring-blue-500"
                    />
                    <.button
                      type="submit"
                      class="text-xs px-3 py-1 text-zinc-900 hover:underline hover:bg-transparent bg-transparent"
                    >
                      Save
                    </.button>
                  </form>
                </div>
              </div>

              <div class="flex items-center gap-2 ml-4">
                <%= if link.image_url do %>
                  <img
                    src={link.image_url}
                    alt="Preview"
                    class="w-16 h-16 object-cover rounded"
                    loading="lazy"
                  />
                <% end %>
                <button
                  phx-click="delete"
                  phx-value-id={link.id}
                  class="text-xs text-gray-500 hover:text-red-600 p-2 hover:bg-red-50 rounded"
                >
                  delete
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> reset_form()
      |> assign(:search_query, "")
      |> assign(:links, Links.list_links_for_user(socket.assigns.current_user.id))

    {:ok, socket}
  end

  def handle_event("submit", %{"link" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.current_user.id)

    case Links.create_link(params) do
      {:ok, link} ->
        # Start async task to fetch metadata
        socket =
          start_async(socket, {:fetch_metadata, link.id}, fn ->
            Links.fetch_and_update_metadata(link.id)
          end)

        socket =
          socket
          |> put_flash(:info, "Link created successfully.")
          |> refresh_links()
          |> reset_form()

        {:noreply, socket}

      {:error, _changeset} ->
        socket = put_flash(socket, :error, "Link creation failed.")

        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"link" => params}, socket) do
    form =
      %Link{}
      |> Link.changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    socket = assign(socket, :form, form)

    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Links.delete_link(Links.get_link(id)) do
      {:ok, _link} ->
        socket =
          socket
          |> put_flash(:info, "Link deleted successfully.")
          |> refresh_links()

        {:noreply, socket}

      {:error, _changeset} ->
        socket = put_flash(socket, :error, "Link deletion failed.")

        {:noreply, socket}
    end
  end

  def handle_event("search", %{"q" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> refresh_links()

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:search_query, "")
      |> refresh_links()

    {:noreply, socket}
  end

  def handle_event("save_tags", %{"link-id" => link_id, "tags" => tag_string}, socket) do
    case Links.get_link_with_tags(link_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Link not found.")}

      link ->
        # Parse the tag string into a list of tag names
        tag_names =
          tag_string
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))

        case Links.set_link_tags(link, tag_names) do
          {:ok, _updated_link} ->
            socket = refresh_links(socket)

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to update tags.")}
        end
    end
  end

  def handle_async({:fetch_metadata, _link_id}, {:ok, {:ok, _updated_link}}, socket) do
    # Metadata fetch succeeded, refresh the links list
    socket = refresh_links(socket)
    {:noreply, socket}
  end

  def handle_async({:fetch_metadata, _link_id}, {:ok, {:error, _reason}}, socket) do
    # Metadata fetch failed, but we still want to refresh to show the error state
    socket = refresh_links(socket)
    {:noreply, socket}
  end

  def handle_async({:fetch_metadata, _link_id}, {:exit, reason}, socket) do
    # Async task crashed
    require Logger

    Logger.warning("Link metadata fetch crashed: #{inspect(reason)}")
    {:noreply, socket}
  end

  defp reset_form(socket) do
    form =
      %Link{}
      |> Link.changeset()
      |> to_form()

    assign(socket, :form, form)
  end

  defp refresh_links(socket) do
    links = Links.search_links_for_user(socket.assigns.current_user.id, socket.assigns.search_query)
    assign(socket, :links, links)
  end
end
