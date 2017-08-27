defmodule Cortex.FileWatcher do
  @moduledoc false

  alias Cortex.Controller

  require Logger

  use GenServer

  @watched_dirs ["lib/", "test/", "apps/"]

  ##########################################
  # Public API
  ##########################################

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end


  ##########################################
  # GenServer Callbacks
  ##########################################

  def init(_) do
    dirs =
      @watched_dirs
      |> Enum.filter(&File.dir?/1)

    {:ok, watcher_pid} =
      FileSystem.start_link(dirs: dirs)

    FileSystem.subscribe(watcher_pid)

    {:ok, %{watcher_pid: watcher_pid}}
  end

  def handle_info({:file_event, watcher_pid, {path, _events}}, %{watcher_pid: watcher_pid}=state) do
    GenServer.cast(Controller, {:file_changed, file_type(path), path})
    {:noreply, state}
  end

  def handle_info({:file_event, watcher_pid, :stop}, %{watcher_pid: watcher_pid}=state) do
    Logger.info "File watcher stopped."
    {:noreply, state}
  end

  def handle_info(data, state) do
    Logger.info "Get unexcepted message #{inspect data}, ignore..."
    {:noreply, state}
  end


  ##########################################
  # Private Helpers
  ##########################################

  # public only because it is tested
  def file_type(path) do
    is_elixir_file? =
      Regex.match?(~r/\/(\w|_)+\.exs?/, path)

    cond do
      is_elixir_file? and Regex.match?(~r/lib\//, path) ->
        :lib

      is_elixir_file? and Regex.match?(~r/test\//, path) ->
        :test

      true ->
        :unknown
    end
  end
end
