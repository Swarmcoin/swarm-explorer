defmodule ZcashExplorerWeb.NetworkLabelTest do
  @moduledoc """
  Every page names its network three times, all from the one runtime switch
  `ZcashExplorer.Swarm.mainnet?/0`: a ribbon as the first element of the page,
  a chip beside the header wordmark, and the start of the document title.

  On 2026-09-27 the testnet explorer was taken for the mainnet twice: the
  plain name explore.swarm.green serves the testnet, and the only label was
  small print. These tests render real pages, through the router and the
  layouts, with the network configured as the testnet and as the mainnet.

  `async: false`, and the profile is restored after each test: the network is
  application environment, which every other test reads.
  """
  use ZcashExplorerWeb.ConnCase, async: false

  alias ZcashExplorer.Swarm
  alias ZcashExplorerWeb.LayoutView

  @key ZcashExplorer.Swarm

  @mainnet_url "https://mainnet.explore.swarm.green/"
  @testnet_url "https://testnet.explore.swarm.green/"

  # A 64-hex transaction id the (absent) node cannot know: a 404 page rendered
  # through the layouts.
  @unknown_txid String.duplicate("ab", 32)

  setup do
    original = Application.get_env(:zcash_explorer, @key, [])
    on_exit(fn -> Application.put_env(:zcash_explorer, @key, original) end)
    {:ok, original: original}
  end

  defp network(%{original: original}, name, kind \\ nil) do
    Application.put_env(
      :zcash_explorer,
      @key,
      Keyword.merge(original, network_name: name, network_kind: kind)
    )
  end

  # Pages rendered through the router: controller pages (root + app layout),
  # the not-found pages, a LiveView route (root + live layout) and an error
  # Phoenix renders itself.
  defp pages(conn) do
    [
      {"/", conn |> get("/") |> html_response(200)},
      {"/broadcast", conn |> get("/broadcast") |> html_response(200)},
      {"/search?qs=nope", conn |> get("/search", qs: "nope") |> html_response(404)},
      {"/transactions/<unknown>",
       conn |> get("/transactions/#{@unknown_txid}") |> html_response(404)},
      {"/metrics/block_count", conn |> get("/metrics/block_count") |> html_response(200)},
      {"/no-such-page", router_error(conn, "/no-such-page")}
    ]
  end

  # An unknown path is rendered by Phoenix itself (config :render_errors), not
  # by a controller.
  defp router_error(conn, path) do
    {404, _headers, body} = assert_error_sent(404, fn -> get(conn, path) end)
    body
  end

  defp title(html) do
    [_, title] = Regex.run(~r{<title[^>]*>([^<]*)</title>}, html)
    title
  end

  # The ribbon's cross-link is the one place a mainnet page may say "testnet".
  defp without_network_switch(html),
    do: Regex.replace(~r{<a [^>]*data-network-switch[^>]*>.*?</a>}s, html, "")

  describe "on the testnet" do
    setup ctx do
      network(ctx, "SwarmTestnet")
      :ok
    end

    test "every page opens with the amber ribbon and links the mainnet explorer", %{conn: conn} do
      for {path, html} <- pages(conn) do
        assert html =~ ~r/<body>\s*<div class="sw-net-ribbon sw-net-ribbon-testnet"/,
               "#{path}: the ribbon is not the first element of the page"

        assert html =~ "SWARM TESTNET</strong> &middot; test coins, no value", path

        assert html =~
                 ~s(href="#{@mainnet_url}" data-network-switch>Mainnet explorer&nbsp;&rarr;</a>),
               path

        refute html =~ "sw-net-ribbon-mainnet", path
        # The bare name is the one that may be repointed; it is never linked.
        refute html =~ "//explore.swarm.green", path
      end
    end

    test "every title starts with the network", %{conn: conn} do
      for {path, html} <- pages(conn) do
        assert String.starts_with?(title(html), "SWARM Testnet Explorer"), path
      end

      assert conn |> get("/") |> html_response(200) |> title() ==
               "SWARM Testnet Explorer · Search the SwarmTestnet chain"

      assert conn |> router_error("/no-such-page") |> title() ==
               "SWARM Testnet Explorer · Not Found"
    end

    test "the header carries the amber chip on every page with a header", %{conn: conn} do
      for {path, html} <- pages(conn), path not in ["/metrics/block_count", "/no-such-page"] do
        assert html =~
                 ~s(<span class="sw-net-chip sw-net-chip-testnet" data-network-chip="testnet">TESTNET</span>),
               path
      end
    end

    test "the card and footer wording is unchanged", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)
      assert html =~ "SwarmTestnet &middot; TEST COINS, NO VALUE"
      assert html =~ "SWARM TESTNET &mdash; TEST COINS HAVE NO VALUE"
    end

    test "/healthz names the network and its kind", %{conn: conn} do
      body = conn |> get("/healthz") |> json_response(200)
      assert body["network"] == "SwarmTestnet"
      assert body["network_kind"] == "testnet"
    end
  end

  describe "on the mainnet" do
    setup ctx do
      network(ctx, "SwarmMainnet")
      :ok
    end

    test "every page opens with the green ribbon and links the testnet explorer", %{conn: conn} do
      for {path, html} <- pages(conn) do
        assert html =~ ~r/<body>\s*<div class="sw-net-ribbon sw-net-ribbon-mainnet"/,
               "#{path}: the ribbon is not the first element of the page"

        assert html =~ "<strong>SWARM MAINNET</strong>", path

        assert html =~
                 ~s(href="#{@testnet_url}" data-network-switch>Testnet explorer&nbsp;&rarr;</a>),
               path

        refute html =~ "sw-net-ribbon-testnet", path
        refute html =~ "//explore.swarm.green", path
      end
    end

    test "no page promises test coins or says no value", %{conn: conn} do
      for {path, html} <- pages(conn) do
        # With no node the shielded-pool card says "The node reports no value
        # pools yet", which is about the node, not about the coins.
        refute html =~ ~r/no value(?! pools)/i, path
        refute html =~ ~r/test coins/i, path
        # "testnet" only in the cross-link to the other explorer.
        refute without_network_switch(html) =~ ~r/testnet/i, path
      end
    end

    test "every title starts with the network", %{conn: conn} do
      for {path, html} <- pages(conn) do
        assert String.starts_with?(title(html), "SWARM Mainnet Explorer"), path
      end

      assert conn |> get("/") |> html_response(200) |> title() ==
               "SWARM Mainnet Explorer · Search the SwarmMainnet chain"
    end

    test "the header carries the green chip", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~
               ~s(<span class="sw-net-chip sw-net-chip-mainnet" data-network-chip="mainnet">MAINNET</span>)

      refute html =~ "sw-net-chip-testnet"
    end

    test "/healthz names the network and its kind", %{conn: conn} do
      body = conn |> get("/healthz") |> json_response(200)
      assert body["network"] == "SwarmMainnet"
      assert body["network_kind"] == "mainnet"
    end
  end

  describe "the switch" do
    test "a name that is not positively the mainnet keeps the amber ribbon", ctx do
      for name <- ["", "Regtest", "SwarmMian"] do
        network(ctx, name)
        html = ctx.conn |> get("/broadcast") |> html_response(200)
        assert html =~ "sw-net-ribbon-testnet", inspect(name)
        assert html =~ "test coins, no value", inspect(name)
      end
    end

    test "SWARM_NETWORK_KIND wins over the name, both ways", ctx do
      network(ctx, "SwarmTestnet", "mainnet")
      assert ctx.conn |> get("/broadcast") |> html_response(200) =~ "sw-net-ribbon-mainnet"

      network(ctx, "SwarmMainnet", "testnet")
      assert ctx.conn |> get("/broadcast") |> html_response(200) =~ "sw-net-ribbon-testnet"
    end
  end

  describe "document_title/1" do
    setup ctx do
      network(ctx, "SwarmTestnet")
      :ok
    end

    test "puts the network first and does not say SWARM twice" do
      assert LayoutView.document_title(nil) == "SWARM Testnet Explorer"
      assert LayoutView.document_title("") == "SWARM Testnet Explorer"
      assert LayoutView.document_title("SWARM block 343") == "SWARM Testnet Explorer · Block 343"

      assert LayoutView.document_title("SWARM latest blocks") ==
               "SWARM Testnet Explorer · Latest blocks"

      assert LayoutView.document_title("Nothing found") ==
               "SWARM Testnet Explorer · Nothing found"

      assert LayoutView.document_title("Broadcast a raw SWARM transaction") ==
               "SWARM Testnet Explorer · Broadcast a raw SWARM transaction"
    end

    test "follows the switch", ctx do
      network(ctx, "SwarmMainnet")
      assert LayoutView.document_title("SWARM block 7") == "SWARM Mainnet Explorer · Block 7"
      assert Swarm.explorer_title() == "SWARM Mainnet Explorer"
      assert Swarm.network_label() == "Mainnet"
    end

    test "an error page Phoenix renders is titled by its status" do
      assert LayoutView.error_title(%{status: 404, reason: :any}) == "Not Found"
      assert LayoutView.error_title(%{status: 500, reason: :any}) == "Internal Server Error"
      assert LayoutView.error_title(%{page_title: "x"}) == nil
    end
  end

  test "the cross-links are the explicit hostnames" do
    assert Swarm.mainnet_explorer_url() == @mainnet_url
    assert Swarm.testnet_explorer_url() == @testnet_url
  end
end
