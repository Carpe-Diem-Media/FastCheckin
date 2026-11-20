defmodule FastCheck.Cache.CacheManagerPatternTest do
  use ExUnit.Case, async: false

  alias FastCheck.Cache.CacheManager

  @topic "fastcheck:cache:invalidate"
  @config_key {CacheManager, :config}
  @keys [
    "sales:event:1:offers",
    "sales:event:1:offers:vip",
    "sales:event:10:offers",
    "sales:event:11:offers",
    "sales:offers:active:event:1:vip",
    "sales:offers:active:event:10:vip",
    "occupancy:event:1:breakdown",
    "occupancy:event:10:breakdown",
    "occupancy:gate:1:breakdown",
    "axam:literal.a:one",
    "axam:literalXa:one",
    "axam:expired:one"
  ]

  setup_all do
    # In normal CI the application owns these processes. The no-app invocation
    # starts only the in-memory dependencies and manager for this module.
    {:ok, _} = Application.ensure_all_started(:cachex)
    {:ok, _} = Application.ensure_all_started(:phoenix_pubsub)

    if is_nil(Process.whereis(FastCheck.PubSub)) do
      start_supervised!({Phoenix.PubSub, name: FastCheck.PubSub})
    end

    if is_nil(Process.whereis(CacheManager)) do
      start_supervised!({CacheManager, cache_name: :axam_pattern_test_cache})
    end

    :ok
  end

  setup do
    :ok = Phoenix.PubSub.subscribe(FastCheck.PubSub, @topic)
    cache = :persistent_term.get(@config_key).cache_name
    :sys.get_state(CacheManager)
    Enum.each(@keys, &Cachex.del(cache, &1))

    on_exit(fn ->
      Enum.each(@keys, &Cachex.del(cache, &1))
    end)

    %{cache: cache}
  end

  test "offer patterns preserve unrelated event and namespace values and TTL", %{cache: cache} do
    Enum.each(@keys, &Cachex.put(cache, &1, {:value, &1}, ttl: 120_000))
    {:ok, ttl_before} = Cachex.ttl(cache, "occupancy:event:1:breakdown")

    assert {:ok, 2} = CacheManager.invalidate_pattern("sales:event:1:offers*")
    assert_receive {:cache_invalidate, "sales:event:1:offers*"}
    :sys.get_state(CacheManager)
    assert {:ok, nil} = Cachex.get(cache, "sales:event:1:offers")
    assert {:ok, nil} = Cachex.get(cache, "sales:event:1:offers:vip")
    assert {:ok, {:value, "sales:event:10:offers"}} = Cachex.get(cache, "sales:event:10:offers")
    assert {:ok, {:value, "sales:event:11:offers"}} = Cachex.get(cache, "sales:event:11:offers")

    assert {:ok, {:value, "sales:offers:active:event:1:vip"}} =
             Cachex.get(cache, "sales:offers:active:event:1:vip")

    assert {:ok, {:value, "occupancy:event:1:breakdown"}} =
             Cachex.get(cache, "occupancy:event:1:breakdown")

    assert {:ok, ttl_after} = Cachex.ttl(cache, "occupancy:event:1:breakdown")
    assert ttl_after > 0 and ttl_after <= ttl_before

    assert {:ok, 1} = CacheManager.invalidate_pattern("sales:offers:active:event:1:*")
    assert_receive {:cache_invalidate, "sales:offers:active:event:1:*"}
    :sys.get_state(CacheManager)
    assert {:ok, nil} = Cachex.get(cache, "sales:offers:active:event:1:vip")

    assert {:ok, {:value, "sales:offers:active:event:10:vip"}} =
             Cachex.get(cache, "sales:offers:active:event:10:vip")
  end

  test "occupancy and literal patterns match their own keys only", %{cache: cache} do
    Enum.each(@keys, &Cachex.put(cache, &1, :kept))
    assert {:ok, 1} = CacheManager.invalidate_pattern("occupancy:event:1:*")
    assert_receive {:cache_invalidate, "occupancy:event:1:*"}
    :sys.get_state(CacheManager)
    assert {:ok, nil} = Cachex.get(cache, "occupancy:event:1:breakdown")
    assert {:ok, :kept} = Cachex.get(cache, "occupancy:event:10:breakdown")
    assert {:ok, :kept} = Cachex.get(cache, "occupancy:gate:1:breakdown")
    assert {:ok, 1} = CacheManager.invalidate_pattern("axam:literal.a:*")
    assert_receive {:cache_invalidate, "axam:literal.a:*"}
    :sys.get_state(CacheManager)
    assert {:ok, :kept} = Cachex.get(cache, "axam:literalXa:one")
  end

  test "remote invalidation does not rebroadcast", %{cache: cache} do
    Cachex.put(cache, "sales:event:1:offers", :delete)
    Cachex.put(cache, "sales:event:10:offers", :keep)
    send(Process.whereis(CacheManager), {:cache_invalidate, "sales:event:1:offers*"})
    :sys.get_state(CacheManager)
    assert {:ok, nil} = Cachex.get(cache, "sales:event:1:offers")
    assert {:ok, :keep} = Cachex.get(cache, "sales:event:10:offers")
    refute_receive {:cache_invalidate, _}, 100
  end

  test "expired entries are not counted and invalid patterns do not delete", %{cache: cache} do
    Cachex.put(cache, "axam:expired:one", :expired, ttl: 1)
    # Let the TTL elapse without reading or deleting the Cachex entry.
    receive do
    after
      10 -> :ok
    end

    Cachex.put(cache, "axam:literal.a:one", :keep)
    assert {:ok, 0} = CacheManager.invalidate_pattern("axam:expired:*")
    assert_receive {:cache_invalidate, "axam:expired:*"}
    :sys.get_state(CacheManager)
    assert {:error, :invalid_pattern} = CacheManager.invalidate_pattern("")
    assert {:error, :invalid_pattern} = CacheManager.invalidate_pattern("*")
    assert {:error, :invalid_pattern} = CacheManager.invalidate_pattern(<<255>>)
    assert {:error, :invalid_pattern} = CacheManager.invalidate_pattern(nil)
    send(Process.whereis(CacheManager), {:cache_invalidate, nil})
    :sys.get_state(CacheManager)
    assert {:ok, :keep} = Cachex.get(cache, "axam:literal.a:one")
    refute_receive {:cache_invalidate, _}, 100
  end

  test "an exact pattern deletes only that live key", %{cache: cache} do
    Cachex.put(cache, "sales:event:1:offers", :delete)
    Cachex.put(cache, "sales:event:1:offers:vip", :keep)
    assert {:ok, 1} = CacheManager.invalidate_pattern("sales:event:1:offers")
    assert_receive {:cache_invalidate, "sales:event:1:offers"}
    :sys.get_state(CacheManager)
    assert {:ok, :keep} = Cachex.get(cache, "sales:event:1:offers:vip")
    assert {:ok, 0} = CacheManager.invalidate_pattern("sales:event:1:offers")
    assert_receive {:cache_invalidate, "sales:event:1:offers"}
    :sys.get_state(CacheManager)
  end

  test "invalidation covers more than one Cachex stream batch", %{cache: cache} do
    keys = for number <- 1..80, do: "axam:batch:#{number}"
    on_exit(fn -> Enum.each(keys, &Cachex.del(cache, &1)) end)
    Enum.each(keys, &Cachex.put(cache, &1, :delete))

    assert {:ok, 80} = CacheManager.invalidate_pattern("axam:batch:*")
    assert_receive {:cache_invalidate, "axam:batch:*"}
    :sys.get_state(CacheManager)
    assert Enum.all?(keys, &(Cachex.get(cache, &1) == {:ok, nil}))
  end

  test "unavailable cache returns an error without broadcasting" do
    original = :persistent_term.get(@config_key)
    :persistent_term.put(@config_key, %{original | cache_name: :axam_missing_cache})

    try do
      assert {:error, :cache_unavailable} = CacheManager.invalidate_pattern("axam:*")
      refute_receive {:cache_invalidate, _}, 100
    after
      :persistent_term.put(@config_key, original)
    end
  end

  test "Cachex errors are returned without broadcasting" do
    original = :persistent_term.get(@config_key)
    pid = spawn(fn -> receive do: (:stop -> :ok) end)
    true = Process.register(pid, :axam_unregistered_cache)
    :persistent_term.put(@config_key, %{original | cache_name: :axam_unregistered_cache})

    try do
      assert {:error, :no_cache} = CacheManager.invalidate_pattern("axam:*")
      refute_receive {:cache_invalidate, _}, 100
    after
      :persistent_term.put(@config_key, original)
      send(pid, :stop)
    end
  end
end
