defmodule Rpi.I2c do
  @moduledoc """
  Documentation for `I2C`.
  RaspberryPi I2Cモジュール
  """

  use GenServer
  require Logger

  @doc """
  start_link
  application.exのworkerから起動
  ## Parameter
  - pname:プロセス名
  - i2c_bus:I2Cのバス名
  """
  def start_link({pname, i2c_bus}) do
    Logger.info("* #{__MODULE__}: start_link")
    GenServer.start_link(__MODULE__, i2c_bus, name: pname)
  end

  ###################################################################
  # ヘルパー関数

  @doc """
  クライアント側API / ヘルパー関数
  出力：true
  ## Example
  """
  def write(pname, addr, data, retries \\ []) do
    GenServer.cast(pname, {:write, addr, data, retries})
  end

  def read(pname, addr, bytes, retries \\ []) do
    GenServer.call(pname, {:read, addr, bytes, retries})
  end

  def writeread(pname, addr, bytes, retries \\ []) do
    GenServer.call(pname, {:writeread, addr, bytes, retries})
  end

  def stop(pname), do: GenServer.stop(pname)

  ###################################################################
  # 実装

  @doc """
  init
  初期化
  ## Parameter
  - i2c_bus:I2Cのバス名
  """
  @impl GenServer
  def init(i2c_bus) do
    Logger.debug("* #{__MODULE__}: initialize I2C Bus #{i2c_bus}")
    Circuits.I2C.open(i2c_bus)
  end

  @doc """
  コールバック関数：書き込み
  ## Parameter
  ## 例
  """
  @impl GenServer
  def handle_cast({:write, addr, data, retries}, i2cref) do
    Circuits.I2C.write(i2cref, addr, data, retries)
    {:noreply, i2cref}
  end

  @doc """
  コールバック関数：読み込み
  ## Parameter
  ## 例
  """
  @impl GenServer
  def handle_call({:read, addr, bytes, retries}, _from, i2cref) do
    {:reply, {:ok, Circuits.I2C.read(i2cref, addr, bytes, retries)}, i2cref}
  end

  @doc """
  コールバック関数：書き・読み込み
  ## Parameter
  ## 例
  """
  @impl GenServer
  def handle_call({:writeread, addr, bytes, retries}, _from, i2cref) do
    {:reply, {:ok, Circuits.I2C.write_read(i2cref, addr, bytes, retries)}, i2cref}
  end

  @doc """
  コールバック関数：終了時処理
  """
  @impl GenServer
  def terminate(reason, i2cref) do
    Logger.debug("#{__MODULE__} terminate: #{inspect(reason)}")
    Circuits.I2C.close(i2cref)
    reason
  end
end
