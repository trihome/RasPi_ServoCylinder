defmodule Worker do
  @moduledoc """
  Documentation for `Worker`.
  機能：全体制御

  ##接続
  IN      Physical
  -----------------
  X0      21  リセットPL
  X1      20  トグルSW
  X2      16  スタートPL
  X3      12  ストップPB
  -----------------
  OUT     Physical
  -----------------
  Y0      26  SignalTower R
  Y1      19  SignalTower Y
  Y2      13  SignalTower G
  Y3      6   リセットPB
  """

  use GenServer
  use Bitwise
  require Logger
  alias Rpi.Gpio

  @doc """
  start_link
  application.exのworkerから起動

  ## Parameter
  - state:保持データ
  - opts:起動オプション
  """
  def start_link(state, opts) do
    Logger.info("* #{__MODULE__}: start_link")
    GenServer.start_link(__MODULE__, state, opts)
  end

  @doc """
  init
  GenServer起動時の初期化

  ## Parameter
    - state:保持データ
  """
  @impl GenServer
  def init(state) do
    Logger.debug("* #{__MODULE__}: init")
    {:ok, state}
  end

  @doc """
  """
  @impl GenServer
  def handle_info(msg, gpioref) do
    Logger.warn("#{__MODULE__} get_message: #{inspect(msg)}")
    {:noreply, gpioref}
  end

  @impl GenServer
  def terminate(reason, gpioref) do
    Logger.debug("#{__MODULE__} terminate: #{inspect(reason)}")
    reason
  end

  @doc """
  ビットパルス出力
  """
  def pulse(port) do
    Gpio.write(1, port)
    Process.sleep(100)
    Gpio.write(0, port)
  end

  @doc """
  ビットパルス出力
  """
  def getstate() do
    IO.puts(" リセットPB : #{Gpio.read(:in_plpb_r)}")
    IO.puts(" トグルSW : #{Gpio.read(:in_tgsw)}")
    IO.puts(" スタートPB : #{Gpio.read(:in_plpb_1)}")
    IO.puts(" ストップPB : #{Gpio.read(:in_plpb_2)}")
  end

  @doc """
  起動操作
  ## Parameter
  - state:前回の状態
  """
  def state(state, :kidou) do
    # 信号のチェック：スタート、ストップボタン
    case {Gpio.read(:in_plpb_1), Gpio.read(:in_plpb_2)} do
      # 起動条件が揃っていれば1
      {1, 0} -> 1
      # 停止条件が揃っていれば0
      {0, 1} -> 0
      # 上記以外は維持
      {_, _} -> state
    end
  end

  @doc """
  リセット操作
  """
  def check(:reset) do
    # 信号のチェック：
    Gpio.read(:in_plpb_r)
  end

  @doc """
  トグルSW操作
  """
  def check(:toggle) do
    # 信号のチェック：
    Gpio.read(:in_tgsw)
  end
end
