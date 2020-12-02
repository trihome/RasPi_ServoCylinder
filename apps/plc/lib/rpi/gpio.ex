defmodule Rpi.Gpio do
  @moduledoc """
  Documentation for `GPIO`.
  RaspberryPi GPIOモジュール
  """

  use GenServer
  require Logger

  @doc """
  start_link
  application.exのworkerから起動
  ## Parameter
  - pname:プロセス名
  - gpio_no:GPIO番号
  - in_out:入出力方向
  - ppid:メッセージを送る先の pid を指定
  """
  def start_link({pname, gpio_no, in_out}, ppid \\ []) do
    Logger.info("* #{__MODULE__}: start_link")
    GenServer.start_link(__MODULE__, {gpio_no, in_out, ppid}, name: pname)
  end

  ###################################################################
  # ヘルパー関数

  @doc """
  クライアント側API / ヘルパー関数
  出力：true
  ## Example
  """
  def write(true, pname), do: GenServer.cast(pname, {:write, 1})

  @doc """
  クライアント側API / ヘルパー関数
  出力：false
  ## Example
  """
  def write(false, pname), do: GenServer.cast(pname, {:write, 0})

  @doc """
  クライアント側API / ヘルパー関数
  直接書き込み
  ## Example
  """
  def write(val, pname), do: GenServer.cast(pname, {:write, val})

  @doc """
  クライアント側API / ヘルパー関数
  直接読み込み
  ## Example
  """
  def read(pname) do
    {:ok, ret} = GenServer.call(pname, :read)
    ret
  end

  ###################################################################
  # 実装

  @doc """
  init
  初期化：出力
  ## Parameter
  - gpio_no:GPIO番号
  - in_out:入出力方向＝入力
  """
  @impl GenServer
  def init({gpio_no, in_out = :output, _ppid}) do
    # GPIO出力の初期化
    Logger.debug("* #{__MODULE__}: initialize gpio#{gpio_no}/:output")
    Circuits.GPIO.open(gpio_no, in_out)
  end

  @doc """
  init
  初期化：入力
  ## Parameter
  - gpio_no:GPIO番号
  - in_out:入出力方向＝出力
  - ppid:入力コールバックメッセージを送る先の pid を指定
  """
  @impl GenServer
  def init({gpio_no, in_out = :input, ppid}) do
    # GPIO出力の初期化
    {:ok, gpioref} = Circuits.GPIO.open(gpio_no, in_out)
    Circuits.GPIO.set_interrupts(gpioref, :both, receiver: ppid)
    Logger.debug("* #{__MODULE__}: initialize gpio#{gpio_no}/:input, #{ppid}:pid")
    {:ok, gpioref}
  end

  @doc """
  コールバック関数：GPIO出力
  ## パラメータ
  - gpioref: start_link/3 で指定したプロセス名が入る
  ## 例
  """
  @impl GenServer
  def handle_cast({:write, val}, gpioref) do
    Circuits.GPIO.write(gpioref, val)
    {:noreply, gpioref}
  end

  @doc """
  コールバック関数：GPIO入力
  """
  @impl GenServer
  def handle_call(:read, _from, gpioref) do
    {:reply, {:ok, Circuits.GPIO.read(gpioref)}, gpioref}
  end

  @doc """
  コールバック関数：GPIO入力
  """
  @impl GenServer
  def handle_info(msg, gpioref) do
    Logger.info("#{__MODULE__} get_message: #{inspect(msg)}")
    Circuits.GPIO.set_interrupts(gpioref, :both)
    {:noreply, gpioref}
  end

  @doc """
  コールバック関数：終了時処理
  """
  @impl GenServer
  def terminate(reason, gpioref) do
    Logger.warn("#{__MODULE__} terminate: #{inspect(reason)}")
    Circuits.GPIO.close(gpioref)
    reason
  end
end
