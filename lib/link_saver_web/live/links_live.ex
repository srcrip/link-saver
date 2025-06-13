defmodule LinkSaverWeb.LinksLive do
  @moduledoc false
  use LinkSaverWeb, :live_view

  alias LinkSaver.Links
  alias LinkSaver.Links.Link

  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-lg font-medium mb-4">Links</h1>

      <.form for={@form} phx-submit="submit" phx-change="validate" id="link-form" class="mb-6">
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
          <button type="submit" class="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
            Add Link
          </button>
        </div>
      </.form>

      <%= if @links == [] do %>
        <p class="text-gray-500 text-sm">No links saved yet.</p>
      <% else %>
        <div class="space-y-2">
          <div :for={link <- @links} class="flex items-center justify-between py-2 border-b border-gray-100">
            <div class="flex-1 min-w-0">
              <a
                href={link.url}
                target="_blank"
                rel="noopener noreferrer"
                class="text-blue-600 hover:underline text-sm truncate block"
              >
                {link.url}
              </a>
              <p class="text-xs text-gray-500 mt-1">
                {Calendar.strftime(link.inserted_at, "%Y-%m-%d")}
              </p>
            </div>
            <button
              phx-click="delete"
              phx-value-id={link.id}
              class="text-xs text-gray-500 hover:text-red-600 ml-4"
            >
              delete
            </button>
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
      |> assign(:links, Links.list_links())

    {:ok, socket}
  end

  def handle_event("submit", %{"link" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.current_user.id)

    case Links.create_link(params) do
      {:ok, link} ->
        socket =
          socket
          |> put_flash(:info, "Link created successfully.")
          |> assign(:links, Links.list_links())
          |> reset_form()

        {:noreply, socket}

      {:error, changeset} ->
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
          |> assign(:links, Links.list_links())

        {:noreply, socket}

      {:error, changeset} ->
        socket = put_flash(socket, :error, "Link deletion failed.")

        {:noreply, socket}
    end
  end

  defp reset_form(socket) do
    form =
      %Link{}
      |> Link.changeset()
      |> to_form()

    assign(socket, :form, form)
  end
end
