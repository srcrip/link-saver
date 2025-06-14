Application.ensure_all_started(:mimic)
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(LinkSaver.Repo, :manual)
