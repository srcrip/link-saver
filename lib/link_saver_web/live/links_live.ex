defmodule LinkSaverWeb.LinksLive do
  use LinkSaverWeb, :live_view

  alias LinkSaver.Links
  alias LinkSaver.Links.Link

  def render(assigns) do
    ~H"""
    <.form for={@form} phx-submit="submit" phx-change="validate" id="link-form">
      <.input field={@form[:url]} autocomplete="off" required />
    </.form>

    <ul>
      <li :for={link <- @links} class="flex">
        <a class="grow" href={link.url}><%= link.url %></a>
        <button phx-click="delete" phx-value-id={link.id}>Delete</button>
      </li>
    </ul>
    """
  end

  def mount(_params, _session, socket) do
    form =
      %Link{}
      |> Link.changeset()
      |> to_form()

    socket =
      socket
      |> assign(:form, form)
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

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, "Link creation failed.")

        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"link" => params}, socket) do
    form =
      %Link{}
      |> Link.changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    socket =
      socket
      |> assign(:form, form)

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
        socket =
          socket
          |> put_flash(:error, "Link deletion failed.")

        {:noreply, socket}
    end
  end
end
