defmodule ZcashExplorer.HostnamesTest do
  @moduledoc """
  `EXPLORER_HOSTNAME` names every hostname the explorer is served under.

  Measured against the running container on 2026-09-25, before this change
  (server-access note "Explorer subdomains 2026-09-25", section 1):

      origin https://lwd.swarm.green:8443        -> 101
      origin https://explore.swarm.green         -> 403
      origin https://testnet.explore.swarm.green -> 403

  A page on the second or third name rendered, and its live tiles never
  connected, with nothing in any log. The proxy had to rewrite the `Origin`
  header to the single accepted name. These tests pin the list form, what the
  release boot builds from it, and - against Phoenix itself - which origins the
  result accepts.
  """
  use ExUnit.Case, async: false

  alias ZcashExplorer.Hostnames

  @three "explore.swarm.green,testnet.explore.swarm.green,mainnet.explore.swarm.green"

  @env ~w(EXPLORER_HOSTNAME EXPLORER_PORT EXPLORER_SCHEME PORT
          SECRET_KEY_BASE SESSION_SIGNING_SALT LIVE_VIEW_SIGNING_SALT)

  setup do
    saved = Map.new(@env, fn name -> {name, System.get_env(name)} end)

    on_exit(fn ->
      Enum.each(saved, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Parsing
  # ---------------------------------------------------------------------------

  describe "parse/1" do
    test "unset means localhost, as before" do
      assert Hostnames.parse(nil) == ["localhost"]
    end

    test "a single name is a list of one" do
      assert Hostnames.parse("explore.swarm.green") == ["explore.swarm.green"]
    end

    test "a comma-separated list keeps its order" do
      assert Hostnames.parse(@three) == [
               "explore.swarm.green",
               "testnet.explore.swarm.green",
               "mainnet.explore.swarm.green"
             ]
    end

    test "whitespace around the commas is ignored" do
      assert Hostnames.parse(
               " explore.swarm.green , testnet.explore.swarm.green ,\tlwd.swarm.green"
             ) ==
               ["explore.swarm.green", "testnet.explore.swarm.green", "lwd.swarm.green"]
    end

    test "a scheme prefix and trailing slashes are stripped, and the name is lower-cased" do
      assert Hostnames.parse("https://Explore.Swarm.Green/, HTTP://lwd.swarm.green//") ==
               ["explore.swarm.green", "lwd.swarm.green"]
    end

    test "duplicates are dropped" do
      assert Hostnames.parse("a.example, https://a.example/, b.example, A.EXAMPLE") ==
               ["a.example", "b.example"]
    end

    test "a trailing or doubled comma does not add an empty host" do
      assert Hostnames.parse("a.example,,b.example,") == ["a.example", "b.example"]
    end

    for value <- ["", "   ", ",", " , ,"] do
      test "set to #{inspect(value)} stops the boot, naming the variable" do
        message = raised(fn -> Hostnames.parse(unquote(value)) end)
        assert message =~ "EXPLORER_HOSTNAME"
        assert message =~ "names no host"
      end
    end

    for entry <- [
          "explore.swarm.green/blocks",
          "lwd.swarm.green:8443",
          "*.swarm.green",
          "explore swarm.green"
        ] do
      test "#{inspect(entry)} is not a bare hostname and stops the boot, naming the entry" do
        message = raised(fn -> Hostnames.parse("explore.swarm.green," <> unquote(entry)) end)
        assert message =~ "EXPLORER_HOSTNAME"
        assert message =~ unquote(entry)
        assert message =~ "bare hostname"
      end
    end
  end

  describe "primary/1" do
    test "is the first name" do
      assert Hostnames.primary(Hostnames.parse(@three)) == "explore.swarm.green"
    end
  end

  describe "check_origin/2" do
    test "lists every name as a scheme-less, port-less origin, plus loopback" do
      assert Hostnames.check_origin(Hostnames.parse(@three), "4000") == [
               "//explore.swarm.green",
               "//testnet.explore.swarm.green",
               "//mainnet.explore.swarm.green",
               "//localhost",
               "http://127.0.0.1:4000"
             ]
    end

    test "does not list localhost twice when it is the configured name" do
      assert Hostnames.check_origin(["localhost"], 4000) ==
               ["//localhost", "http://127.0.0.1:4000"]
    end
  end

  # ---------------------------------------------------------------------------
  # What the release boot builds from it (config/runtime.exs)
  # ---------------------------------------------------------------------------

  describe "config/runtime.exs" do
    test "a list feeds every name to check_origin and the first to the URL" do
      set_secrets()
      System.put_env("EXPLORER_HOSTNAME", @three)
      System.delete_env("EXPLORER_PORT")
      System.delete_env("EXPLORER_SCHEME")
      System.delete_env("PORT")

      endpoint = read_runtime!()[:zcash_explorer][ZcashExplorerWeb.Endpoint]

      assert endpoint[:url][:host] == "explore.swarm.green"
      assert endpoint[:url][:port] == 443
      assert endpoint[:url][:scheme] == "https"

      assert endpoint[:check_origin] == [
               "//explore.swarm.green",
               "//testnet.explore.swarm.green",
               "//mainnet.explore.swarm.green",
               "//localhost",
               "http://127.0.0.1:4000"
             ]
    end

    test "the interim single name on port 8443 is unchanged" do
      set_secrets()
      System.put_env("EXPLORER_HOSTNAME", "lwd.swarm.green")
      System.put_env("EXPLORER_PORT", "8443")
      System.put_env("PORT", "4100")

      endpoint = read_runtime!()[:zcash_explorer][ZcashExplorerWeb.Endpoint]

      assert endpoint[:url][:host] == "lwd.swarm.green"
      assert endpoint[:url][:port] == 8443

      assert endpoint[:check_origin] ==
               ["//lwd.swarm.green", "//localhost", "http://127.0.0.1:4100"]
    end

    test "unset still means localhost" do
      set_secrets()
      System.delete_env("EXPLORER_HOSTNAME")
      System.delete_env("PORT")

      endpoint = read_runtime!()[:zcash_explorer][ZcashExplorerWeb.Endpoint]

      assert endpoint[:url][:host] == "localhost"
      assert endpoint[:check_origin] == ["//localhost", "http://127.0.0.1:4000"]
    end

    test "an entry with a port refuses to boot, naming the variable and the entry" do
      set_secrets()
      System.put_env("EXPLORER_HOSTNAME", "explore.swarm.green,lwd.swarm.green:8443")

      message = raised(&read_runtime!/0)
      assert message =~ "EXPLORER_HOSTNAME"
      assert message =~ "lwd.swarm.green:8443"
    end
  end

  # ---------------------------------------------------------------------------
  # What Phoenix makes of the list. This is the check the websocket upgrade
  # goes through, run with the allowlist the release builds.
  # ---------------------------------------------------------------------------

  describe "Phoenix's origin check, given the list" do
    @allowed Hostnames.check_origin(Hostnames.parse(@three), "4000")

    for origin <- [
          "https://explore.swarm.green",
          "https://testnet.explore.swarm.green",
          "https://mainnet.explore.swarm.green",
          # a listed name on another port: the interim endpoint's shape
          "https://explore.swarm.green:8443",
          "http://localhost:4000",
          "http://127.0.0.1:4000"
        ] do
      test "accepts #{origin}" do
        refute origin_refused?(unquote(origin), @allowed)
      end
    end

    for origin <- [
          "https://evil.example.com",
          "https://explore.swarm.green.evil.example.com",
          "https://swarm.green",
          "http://127.0.0.1:4100"
        ] do
      test "refuses #{origin}" do
        assert origin_refused?(unquote(origin), @allowed)
      end
    end

    test "with a single name the other two are refused - the defect this fixes" do
      allowed = Hostnames.check_origin(Hostnames.parse("lwd.swarm.green"), "4000")

      refute origin_refused?("https://lwd.swarm.green:8443", allowed)
      assert origin_refused?("https://explore.swarm.green", allowed)
      assert origin_refused?("https://testnet.explore.swarm.green", allowed)
    end
  end

  # ---------------------------------------------------------------------------

  # Phoenix.Socket.Transport.check_origin/5 is what the websocket upgrade runs.
  # It caches the parsed allowlist per {endpoint, handler}, so each distinct
  # allowlist gets its own handler name and the cache cannot bleed between
  # tests. A refused origin is sent a 403 through the `sender` argument, and
  # Phoenix logs an error for it, which is captured so the suite stays quiet.
  defp origin_refused?(origin, allowed) do
    handler = :"hostnames_test_#{:erlang.phash2(allowed)}"

    conn =
      Plug.Test.conn(:get, "/live/websocket")
      |> Plug.Conn.put_req_header("origin", origin)

    parent = self()

    ExUnit.CaptureLog.capture_log(fn ->
      result =
        Phoenix.Socket.Transport.check_origin(
          conn,
          handler,
          ZcashExplorerWeb.Endpoint,
          [check_origin: allowed],
          fn conn -> Plug.Conn.send_resp(conn) end
        )

      send(parent, {:origin_check, result})
    end)

    receive do
      {:origin_check, %Plug.Conn{halted: true, status: 403}} -> true
      {:origin_check, %Plug.Conn{halted: false}} -> false
    after
      0 -> flunk("the origin check returned nothing")
    end
  end

  defp set_secrets do
    System.put_env("SECRET_KEY_BASE", String.duplicate("s", 64))
    System.put_env("SESSION_SIGNING_SALT", "session-salt")
    System.put_env("LIVE_VIEW_SIGNING_SALT", "live-view-salt")
  end

  # runtime.exs prints a summary line on every boot; only the configuration is
  # wanted here.
  defp read_runtime! do
    parent = self()

    ExUnit.CaptureIO.capture_io(fn ->
      send(parent, {:runtime_config, Config.Reader.read!("config/runtime.exs", env: :prod)})
    end)

    receive do
      {:runtime_config, config} -> config
    after
      0 -> flunk("config/runtime.exs produced nothing")
    end
  end

  defp raised(fun) do
    outcome =
      try do
        fun.()
        :returned
      rescue
        error -> {:raised, Exception.message(error)}
      end

    case outcome do
      {:raised, message} -> message
      :returned -> flunk("expected an exception and none was raised")
    end
  end
end
