# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Sample configuration:
#
config :logger, :console,
  level: :info,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id]

# Configure the main viewport for the Scenic application
config :hmi, :viewport, %{
  name: :main_viewport,
  size: {700, 600},
  default_scene: {Hmi.Scene.Home, nil},
  drivers: [
    %{
      module: Scenic.Driver.Glfw,
      name: :glfw,
      opts: [resizeable: false, title: "hmi"]
    }
  ]
}

# アプリの各種設定
config :plc,
  # 定期実行の間隔(ms)
  auto_interval: 1 * 100
