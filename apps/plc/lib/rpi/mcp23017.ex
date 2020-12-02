defmodule Rpi.Mcp23017 do
  @moduledoc """
  Documentation for `MCP23017`.
  I2Cエキスパンダ・MCP23017制御モジュール
  """

  use Bitwise
  use GenServer
  require Logger
  alias Rpi.I2c

  # モジュールスコープ定数
  # MCP23017 入出力設定レジスタ（変更不可）
  # ■■■入出力方向
  @reg_iodira 0x00
  # (0: 出力  1:入力)
  @reg_iodirb 0x01
  # ■■■I/O 極性
  @reg_ipola 0x02
  # (0: 0='L', 1='H' ; 1: 1='L', 0='H')
  @reg_ipolb 0x03
  # ■■■状態変化割り込み
  @reg_gpintena 0x04
  # (0:無効 1:有効)
  @reg_gpintenb 0x05
  # ■■■状態変化割り込みの規定値
  @reg_defvala 0x06
  # (この値と逆になったら割り込み発生)
  @reg_defvalb 0x07
  # ■■■状態変化割り込みの比較値
  @reg_intcona 0x08
  # (0: 前の値と比較  1:DEFV の値と比較)
  @reg_intconb 0x09
  # ■■■コンフィグレーションレジスタ※
  @reg_iocona 0x0A
  #
  @reg_ioconb 0x0B
  # ■■■プルアップ制御
  @reg_gppua 0x0C
  # (0: プルアップ無効  1:プルアップ有効)
  @reg_gppub 0x0D
  # ■■■割込みフラグレジスタ (INTCAP 又は GPIO リードでクリア)
  @reg_intfa 0x0E
  # (0: 割り込みなし  1:割り込み発生)
  @reg_intfb 0x0F
  # ■■■割込みキャプチャレジスタ
  @reg_intcapa 0x10
  # (割込み発生時の GPIO の値)
  @reg_intcapb 0x11
  # ■■■出力レジスタ
  @reg_gpioa 0x12
  # (GPIOの値)
  @reg_gpiob 0x13
  # ■■■出力ラッチレジスタ
  @reg_olata 0x14
  # (出力ラッチの値)
  @reg_olatb 0x15

  @doc """
  start_link
  application.exのworkerから起動
  ## Parameter
  - pname:プロセス名
  - i2c_pname:I2C制御のプロセス名
  - i2c_addr:制御対象のI2Cアドレス
  """
  def start_link({pname, i2c_pname, i2c_addr}) do
    Logger.info("* #{__MODULE__}: start_link")
    GenServer.start_link(__MODULE__, {pname, i2c_pname, i2c_addr}, name: pname)
  end

  ###################################################################
  # ヘルパー関数

  @doc """
  出力制御：バイトで書き込み
  """
  def puts(value, i2c_pname) do
    GenServer.cast(i2c_pname, {:puts, value})
  end

  @doc """
  出力制御：指定のビットだけ書き込み
  """
  def put(value, bit, i2c_pname) do
    GenServer.cast(i2c_pname, {:put, bit, value})
  end

  @doc """
  入力制御：バイトで読み込み
  同期版
  """
  def getsb(i2c_pname) do
    GenServer.call(i2c_pname, {:gets, @reg_gpiob})
  end

  def getsa(i2c_pname) do
    GenServer.call(i2c_pname, {:gets, @reg_gpioa})
  end

  @doc """
  入力制御：指定のビットだけ読み込み
  同期版
  """
  def getb(bit, i2c_pname) do
    GenServer.call(i2c_pname, {:get, @reg_gpiob, bit})
  end

  def geta(bit, i2c_pname) do
    GenServer.call(i2c_pname, {:get, @reg_gpioa, bit})
  end

  ###################################################################
  # 実装

  @doc """
  init
  初期化
  ## Parameter
  - gpio_no:GPIO番号
  - in_out:入出力方向
  - ppid:メッセージを送る先の pid を指定
  """
  @impl GenServer
  def init({_pname, i2c_pname, i2c_addr}) do
    # I2Cアドレスを16進表記する処理
    str_addr = <<i2c_addr::integer-signed-8>> |> Base.encode16()
    Logger.debug("* #{__MODULE__}: initialize MCP23017 (0x#{str_addr}) over I2C (#{i2c_pname})")
    # MCP23017初期化
    init_ioexp(i2c_pname, i2c_addr)
    {:ok, {i2c_pname, i2c_addr}}
  end

  #  MCP23017の初期化
  ## Parameter
  # - i2c_pname:I2C制御のプロセス名
  # - i2c_addr:制御対象のI2Cアドレス
  defp init_ioexp(i2c_pname, i2c_addr) do
    # PORT A 出力方向に設定
    I2c.write(i2c_pname, i2c_addr, <<@reg_iodira, 0x00>>)
    # PORT A 全消灯
    I2c.write(i2c_pname, i2c_addr, <<@reg_gpioa, 0x00>>)
    # PORT B 入力方向に設定
    I2c.write(i2c_pname, i2c_addr, <<@reg_iodirb, 0xFF>>)
  end

  @doc """
  コールバック関数：出力を直接値で制御(非同期呼び出し)
  ## Parameter
  - gpio_no:GPIO番号
  - in_out:入出力方向
  - ppid:メッセージを送る先の pid を指定
  """
  @impl GenServer
  def handle_cast({:puts, value}, {i2c_pname, i2c_addr}) do
    # PORTAに新しい値を上書き
    I2c.write(i2c_pname, i2c_addr, <<@reg_gpioa, value>>)
    {:noreply, {i2c_pname, i2c_addr}}
  end

  @doc """
  コールバック関数：出力をビット単位で制御する(非同期呼び出し)
  ## Parameter
  - bit:指定のビット番号
  - value:値(0:L, 1:H)
  """
  @impl GenServer
  def handle_cast({:put, bit, value}, {i2c_pname, i2c_addr}) do
    # 現在の出力状況を読み出し
    {_, {_, <<now>>}} = I2c.writeread(i2c_pname, i2c_addr, <<@reg_gpioa>>, 1)

    # ビット計算
    # https://hexdocs.pm/elixir/Bitwise.html
    # 現在の値に対し、指定のビットを新しい値で上書き
    val =
      case {value} do
        # 消灯操作
        {0} -> now &&& bnot(1 <<< bit)
        # 点灯操作
        {_} -> now ||| 1 <<< bit
      end

    # 新しい値を上書き
    I2c.write(i2c_pname, i2c_addr, <<@reg_gpioa, val>>)
    {:noreply, {i2c_pname, i2c_addr}}
  end

  @doc """
  コールバック関数：入力をバイト読み込み(同期呼び出し)
  ## Parameter
  """
  @impl GenServer
  def handle_call({:gets, reg}, _from, {i2c_pname, i2c_addr}) do
    # 現在の入力状況を読み出し
    {_, {_, <<val>>}} = I2c.writeread(i2c_pname, i2c_addr, <<reg>>, 1)
    {:reply, val, {i2c_pname, i2c_addr}}
  end

  @doc """
  コールバック関数：入力をビット読み込み(同期呼び出し)
  ## Parameter
  - bit:指定のビット番号
  """
  @impl GenServer
  def handle_call({:get, reg, bit}, _from, {i2c_pname, i2c_addr}) do
    # 現在の入力状況を読み出し
    {_, {_, <<now>>}} = I2c.writeread(i2c_pname, i2c_addr, <<reg>>, 1)
    # 指定のビットの値を取り出し
    val = now >>> bit &&& 1
    {:reply, val, {i2c_pname, i2c_addr}}
  end

  @doc """
  コールバック関数：終了時
  """
  @impl GenServer
  def terminate(reason, state) do
    Logger.debug("#{__MODULE__} terminate: #{inspect(reason)} #{inspect(state)}")
    reason
  end
end
