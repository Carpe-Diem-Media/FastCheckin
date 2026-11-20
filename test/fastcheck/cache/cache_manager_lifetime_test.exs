defmodule FastCheck.Cache.LifetimePreHook do
  use Cachex.Hook

  def actions, do: [:del]
  def async?, do: false
  def type, do: :pre

  def handle_notify({:del, _}, _result, {owner, target, count}) do
    count = count + 1

    if count == target do
      send(owner, {:cache_hook_paused, self()})
      receive do: (:resume -> :ok)
    end

    {:ok, {owner, target, count}}
  end
end

defmodule FastCheck.Cache.LifetimePostHook do
  use Cachex.Hook

  def actions, do: [:stream, :del]
  def async?, do: false

  def handle_notify({action, _}, _result, {owner, target_action, target_count, count}) do
    count = if action == target_action, do: count + 1, else: count

    if action == target_action and count == target_count do
      send(owner, {:cache_hook_paused, self()})
      receive do: (:resume -> :ok)
    end

    {:ok, {owner, target_action, target_count, count}}
  end
end

defmodule FastCheck.Cache.CacheManagerLifetimeTest do
  use ExUnit.Case, async: false
  require Cachex.Spec
  alias FastCheck.Cache.CacheManager

  @topic "fastcheck:cache:invalidate"
  @config_key {CacheManager, :config}
  @cache :axam_lifetime_cache

  setup_all do
    {:ok, _} = Application.ensure_all_started(:cachex)
    {:ok, _} = Application.ensure_all_started(:phoenix_pubsub)

    if is_nil(Process.whereis(FastCheck.PubSub)) do
      start_supervised!({Phoenix.PubSub, name: FastCheck.PubSub})
    end

    if is_nil(Process.whereis(CacheManager)) do
      start_supervised!({CacheManager, cache_name: :axam_lifetime_default})
    end

    :ok
  end

  setup do
    :ok = Phoenix.PubSub.subscribe(FastCheck.PubSub, @topic)
    :sys.get_state(CacheManager)
    original = :persistent_term.get(@config_key)

    on_exit(fn ->
      :persistent_term.put(@config_key, original)
    end)

    :ok
  end

  test "local caller receives an error when the cache table disappears after stream creation" do
    start_cache(FastCheck.Cache.LifetimePostHook, {self(), :stream, 1, 0})
    run_local_loss()
  end

  test "local caller receives an error when the cache table disappears during traversal" do
    start_cache(FastCheck.Cache.LifetimePostHook, {self(), :del, 25, 0})
    run_local_loss()
  end

  test "local caller receives an error when the cache table disappears during deletion" do
    start_cache(FastCheck.Cache.LifetimePreHook, {self(), 1, 0})
    run_local_loss()
  end

  test "local caller receives an error when the cache shuts down during stream construction" do
    start_cache(FastCheck.Cache.LifetimePostHook, {self(), :stream, 1, 0})
    run_local_loss(:stop_cache)
  end

  test "remote invalidation survives cache loss and does not rebroadcast" do
    start_cache(FastCheck.Cache.LifetimePostHook, {self(), :stream, 1, 0})
    manager = Process.whereis(CacheManager)
    send(manager, {:cache_invalidate, "lifetime:*"})
    assert_receive {:cache_hook_paused, hook}, 2_000
    assert :ok = Supervisor.terminate_child(@cache, Eternal)
    send(hook, :resume)
    assert :sys.get_state(manager, 2_000)
    assert Process.alive?(manager)
    refute_receive {:cache_invalidate, _}, 100
  end

  test "unrelated hook failures remain visible while the cache is alive" do
    assert_unrelated_hook_failure(:kill, :killed)
  end

  test "an unrelated hook shutdown remains visible while the cache is alive" do
    assert_unrelated_hook_failure(:shutdown, :shutdown)
  end

  defp assert_unrelated_hook_failure(signal, expected_reason) do
    start_cache(FastCheck.Cache.LifetimePostHook, {self(), :stream, 1, 0})
    parent = self()

    spawn(fn ->
      result =
        try do
          CacheManager.invalidate_pattern("lifetime:*")
        catch
          :exit, reason -> {:exit, reason}
        end

      send(parent, {:invalidation_result, result})
    end)

    assert_receive {:cache_hook_paused, hook}, 2_000
    Process.exit(hook, signal)

    assert_receive {:invalidation_result, {:exit, {^expected_reason, {GenServer, :call, _}}}},
                   2_000

    assert Process.whereis(@cache)
    refute_receive {:cache_invalidate, _}, 100
  end

  defp start_cache(hook, state) do
    start_supervised!(%{
      id: @cache,
      start:
        {Cachex, :start_link, [@cache, [hooks: [Cachex.Spec.hook(module: hook, state: state)]]]},
      restart: :temporary,
      type: :supervisor
    })

    for n <- 1..80, do: Cachex.put(@cache, "lifetime:#{n}", :value)
    original = :persistent_term.get(@config_key)
    :persistent_term.put(@config_key, %{original | cache_name: @cache})
  end

  defp run_local_loss(mode \\ :remove_table) do
    parent = self()

    spawn(fn ->
      result =
        try do
          CacheManager.invalidate_pattern("lifetime:*")
        rescue
          exception -> {:raised, exception, __STACKTRACE__}
        catch
          kind, reason -> {:caught, kind, reason}
        end

      send(parent, {:invalidation_result, result})
    end)

    assert_receive {:cache_hook_paused, hook}, 2_000

    if mode == :remove_table do
      assert :ok = Supervisor.terminate_child(@cache, Eternal)
      send(hook, :resume)
    else
      assert :ok = Supervisor.stop(@cache)
    end

    assert_receive {:invalidation_result, result}, 2_000
    assert result == {:error, :cache_unavailable}
    refute_receive {:cache_invalidate, _}, 100
  end
end
