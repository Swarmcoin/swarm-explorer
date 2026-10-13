defmodule ZcashExplorer.Snapshot do
  @moduledoc "Timestamped node readings. Missing, failed and stale are never reported as zero."
  alias ZcashExplorer.Cache

  def result(key, {:ok, value}) when not is_nil(value),
    do: {:ok, [{key, value}, {key <> ":observed", System.system_time(:second)}]}

  def result(key, _), do: {:ok, [{key, nil}, {key <> ":observed", nil}]}

  def get(key, default \\ nil, max_age \\ 90) do
    if fresh?(Cache.get(key <> ":observed"), System.system_time(:second), max_age),
      do: Cache.get(key, default), else: default
  end

  def field(key, field), do: get(key, %{}) |> Map.get(field)

  def fresh?(observed, now, max_age) when is_integer(observed),
    do: now >= observed and now - observed <= max_age
  def fresh?(_, _, _), do: false

  def note(key, healthy) do
    case get(key, nil, if(key == "raw_mempool", do: 20, else: 90)) do
      nil -> "Unavailable · waiting for a fresh node response"
      _ -> healthy <> " · updated " <> timestamp(Cache.get(key <> ":observed"))
    end
  end

  defp timestamp(seconds), do: seconds |> DateTime.from_unix!() |> Calendar.strftime("%H:%M:%S UTC")
end
