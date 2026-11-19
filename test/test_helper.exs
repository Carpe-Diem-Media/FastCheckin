ExUnit.start(capture_log: true, exclude: [independent_db: true])
Ecto.Adapters.SQL.Sandbox.mode(FastCheck.Repo, :manual)
