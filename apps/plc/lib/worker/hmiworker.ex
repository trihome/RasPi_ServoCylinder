defmodule HmiWorker do
  use GenServer
  require Logger
  alias Scenic.Sensor

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

    # Sensorを登録
    Sensor.register(:message_lamp, "1.0", "PL Driver")

    {:ok, state}
  end

  def pl(val, id, pname \\ :hmiworker), do: GenServer.cast(pname, {:pl, id, val})

  @doc """
  ランプの点灯
  ## Parameter
    - id:ランプのID
    - val:点灯の値
  """
  @impl GenServer
  def handle_cast({:pl, id, val}, gpioref) do
    # メッセージを送信
    Sensor.publish(:message_lamp, {id, val})
    {:noreply, gpioref}
  end

  @doc """
  コールバック関数：メッセージ受信
  """
  @impl GenServer
  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} get_message: #{inspect(msg)}")
    {:noreply, state}
  end

  @doc """
  コールバック関数：終了時
  """
  @impl GenServer
  def terminate(reason, state) do
    Logger.debug("#{__MODULE__} terminate: #{inspect(reason)}")
    reason
  end
end
