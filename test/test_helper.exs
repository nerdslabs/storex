:ok = LocalCluster.start()

Application.ensure_all_started(:wallaby)
Application.ensure_all_started(:storex)

ExUnit.start(timeout: 600_000)
