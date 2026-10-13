defmodule ZcashExplorerWeb.NodesLive do
  use ZcashExplorerWeb, :live_view
  def render(assigns) do
    ~L"""
    <section class="sw-card sw-data-panel">
      <div class="sw-panel-heading"><h2>Peers reported by this node</h2><span class="sw-caption"><%= @note %></span></div>
      <%= cond do %>
        <% is_nil(@nodes) -> %><div class="sw-empty"><span aria-hidden="true">◌</span><h3>Peer data is unavailable</h3><p>The node has not supplied a fresh peer list. Retrying automatically.</p></div>
        <% @nodes == [] -> %><div class="sw-empty sw-empty-warning"><span aria-hidden="true">⬡</span><h3>No peers reported</h3><p>The node returned an empty peer list. This is a node connectivity or reporting condition, not a count of the entire network.</p><p>New blocks alone do not prove that peer connections are healthy.</p></div>
        <% true -> %><div class="sw-table-scroll" tabindex="0" role="region" aria-label="Peer connections"><table><thead><tr><th>Address</th><th>Software</th><th>Reported height</th></tr></thead><tbody>
        <%= for node <- @nodes do %><tr><td class="sw-mono"><%= node["addr"] || "Unavailable" %></td><td><%= node["subver"] || "Unavailable" %></td><td><%= node["synced_blocks"] || node["startingheight"] || "Unavailable" %></td></tr><% end %>
        </tbody></table></div>
      <% end %>
    </section>
    """
  end
  def mount(_, _, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 5000)
    {:ok, assign(socket, figures())}
  end
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 5000)
    {:noreply, assign(socket, figures())}
  end
  defp figures, do: [nodes: ZcashExplorer.Snapshot.get("zcash_nodes"), note: ZcashExplorer.Snapshot.note("zcash_nodes", "Node response")]
end
