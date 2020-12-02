defmodule Plc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Supervisor
  import Supervisor.Spec

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Plc.Worker.start_link(arg)
      # {Plc.Worker, arg}

      # Scenic
      Scenic.Sensor,

      # GPIO系
      child_spec({Rpi.Gpio, {:out_sigt_r, 26, :output}}, id: :io1),
      child_spec({Rpi.Gpio, {:out_sigt_y, 19, :output}}, id: :io2),
      child_spec({Rpi.Gpio, {:out_sigt_g, 13, :output}}, id: :io3),
      child_spec({Rpi.Gpio, {:out_plpb_r, 6, :output}}, id: :io4),
      child_spec({Rpi.Gpio, {:in_plpb_r, 21, :input}}, id: :io5),
      child_spec({Rpi.Gpio, {:in_tgsw, 20, :input}}, id: :io6),
      child_spec({Rpi.Gpio, {:in_plpb_1, 16, :input}}, id: :io7),
      child_spec({Rpi.Gpio, {:in_plpb_2, 12, :input}}, id: :io8),

      # I2C系
      child_spec({Rpi.I2c, {:io_i2c, "i2c-1"}}, id: :i2c1),
      child_spec({Rpi.Mcp23017, {:io_mcp23017, :io_i2c, 0x20}}, id: :i2c2),

      # メイン処理系
      worker(Rs.Auto, [0, [name: :autors]]),
      worker(HmiWorker, [0, [name: :hmiworker]])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Plc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
