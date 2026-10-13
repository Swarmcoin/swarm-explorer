defmodule ZcashExplorerWeb.RecentTransactionsLive do
  @moduledoc """
  The "Latest transactions" list, with the style guide's state pills.

  SWARM change: an amount is only printed when it is genuinely public. A
  shielded transaction shows the masked glyphs, because the chain does not
  contain a public amount for it and printing its transparent total would say
  something untrue about what was sent.
  """
  use ZcashExplorerWeb, :live_view
  alias ZcashExplorer.Swarm

  @refresh 5_000

  @impl true
  def render(assigns) do
    ~L"""
    <div class="sw-card sw-feed overflow-hidden">
      <div class="flex items-center justify-between px-5 py-4" style="border-bottom:1px solid var(--sw-hairline);">
        <h3 class="font-display text-sm font-semibold">Latest transactions</h3>
        <button class="sw-filter-button" type="button" phx-click="filter" aria-pressed="<%= @hide_coinbase %>">Hide coinbase</button>
      </div>

      <%= if @transaction_cache == [] do %>
        <p class="px-5 py-6 text-sm" style="color:var(--sw-mid);">Waiting for the node&hellip;</p>
      <% end %>

      <%= if @hide_coinbase and @transaction_cache != [] and filtered(@transaction_cache, true) == [] do %>
        <div class="sw-filter-empty"><span aria-hidden="true">◇</span><strong>No other transactions in this sample</strong><p>The recent blocks contain only coinbase transactions. Show coinbase to see the mining rewards.</p></div>
      <% end %>
      <%= for tx <- Enum.take(filtered(@transaction_cache, @hide_coinbase), 6) do %>
        <a href="<%= "/transactions/#{tx["txid"]}" %>"
           class="flex items-center gap-3 px-5 py-3 no-underline"
           style="border-bottom:1px solid var(--sw-hairline-soft);">
          <span class="flex-1 min-w-0">
            <span class="block sw-mono text-[11.5px] truncate" style="color:var(--sw-text2);"><%= tx["txid"] %></span>
            <span class="block sw-mono text-[10.5px]" style="color:var(--sw-dim);">
              block #<%= tx["block_height"] %> &middot; <%= tx["time"] %>
            </span>
          </span>

          <span class="sw-mono text-[11.5px] shrink-0 <%= if tx["masked"], do: "sw-masked" %>"
                style="<%= unless tx["masked"], do: "color:var(--sw-clear-lt);" %>">
            <%= tx["amount"] %><%= unless tx["masked"] do %> <%= @ticker %><small class="block text-right" style="color:var(--sw-mid);font-size:9px;">public outputs</small><% end %>
          </span>

          <span class="<%= tx["pill_class"] %> shrink-0"><%= tx["state"] %></span>
        </a>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, @refresh)
    {:ok, assign(socket, transaction_cache: txs(), ticker: Swarm.ticker(), hide_coinbase: false)}
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, @refresh)
    {:noreply, assign(socket, :transaction_cache, txs())}
  end

  @impl true
  def handle_event("filter", _, socket), do: {:noreply, assign(socket, hide_coinbase: !socket.assigns.hide_coinbase)}

  def filtered(txs, true), do: Enum.reject(txs, &(&1["state"] == "COINBASE"))
  def filtered(txs, false), do: txs
  defp txs, do: ZcashExplorer.Cache.get("transaction_cache", [])
end
