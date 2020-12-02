defmodule Rs.Worker do
  @moduledoc """
  Documentation for `WorkerRs`.
  機能：I2C経由のロボシリンダの制御

  ##接続
  I2CIN   PCONOUT
  -----------------
  X0      3B  完了POS.1bit
  X1      4B  完了POS.2b
  X2      5B  完了POS.4b
  X3      8B  移動中
  X4      9B  位置決め完
  X5      10B  原点復帰完
  X6      12B  運転準備完
  X7      13B  アラーム
  -----------------
  I2COUT  PCONIN
  -----------------
  Y0      3A  移動POS.1bit
  Y1      4A  移動POS.2b
  Y2      5A  移動POS.4b
  Y3      8A  一時停止
  Y4      9A  スタート
  Y5      10A  原点復帰開始
  Y6      11A  サーボON
  Y7      12A  リセット
  """

  use GenServer
  use Bitwise
  require Logger
  alias Rpi.Mcp23017
  alias HmiWorker

  # モジュールスコープ定数
  # MCP23017 入出力設定レジスタ（変更不可）
  # ■■■出力側
  @reg_ysetpos1 0
  @reg_ysetpos2 1
  @reg_ysetpos4 2
  @reg_ypause 3
  @reg_ystart 4
  @reg_yorigin 5
  @reg_ysvon 6
  @reg_yreset 7
  # ■■■入力側
  @reg_xgetpos1 0
  @reg_xgetpos2 1
  @reg_xgetpos4 2
  @reg_xmove 3
  @reg_xposdone 4
  @reg_xorgdone 5
  @reg_xready 6
  @reg_xalarm 7

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
  def wp(bit) do
    w(1, bit)
    Process.sleep(100)
    w(0, bit)
  end

  @doc """
  ビット出力
  ## Parameter
    - val:書き込み先
    - bit:読み込み先ビット
  """
  defp w(val, bit) do
    Rpi.Mcp23017.put(val, bit, :io_mcp23017)
  end

  @doc """
  ビット入力
  ## Parameter
    - bit:読み込み先ビット
  """
  defp r(bit) do
    Rpi.Mcp23017.getb(bit, :io_mcp23017)
  end

  @doc """
  ロボシリンダの状態取得
  """
  def getstate() do
    val = Rpi.Mcp23017.getsb(:io_mcp23017)
    IO.puts(" 完了POS.1bit : #{val &&& 1}")
    IO.puts(" 完了POS.2bit : #{val >>> 1 &&& 1}")
    IO.puts(" 完了POS.4bit : #{val >>> 2 &&& 1}")
    IO.puts(" 移動中       : #{val >>> 3 &&& 1}")
    IO.puts(" 位置決め完   : #{val >>> 4 &&& 1}")
    IO.puts(" 原点復帰完   : #{val >>> 5 &&& 1}")
    IO.puts(" 運転準備完   : #{val >>> 6 &&& 1}")
    IO.puts(" アラーム^    : #{val >>> 7 &&& 1}")
  end

  @doc """
  ロボシリンダの状態取得
  HMI更新
  """
  def getstate(:hmi) do
    # I2C入力
    valb = Rpi.Mcp23017.getsb(:io_mcp23017)
    HmiWorker.pl(valb &&& 1, :pl_i2cx0)
    HmiWorker.pl(valb >>> 1 &&& 1, :pl_i2cx1)
    HmiWorker.pl(valb >>> 2 &&& 1, :pl_i2cx2)
    HmiWorker.pl(valb >>> 3 &&& 1, :pl_i2cx3)
    HmiWorker.pl(valb >>> 4 &&& 1, :pl_i2cx4)
    HmiWorker.pl(valb >>> 5 &&& 1, :pl_i2cx5)
    HmiWorker.pl(valb >>> 6 &&& 1, :pl_i2cx6)
    HmiWorker.pl(valb >>> 7 &&& 1, :pl_i2cx7)
    # I2C出力
    vala = Rpi.Mcp23017.getsa(:io_mcp23017)
    HmiWorker.pl((vala &&& 1) * 2, :pl_i2cy0)
    HmiWorker.pl((vala >>> 1 &&& 1) * 2, :pl_i2cy1)
    HmiWorker.pl((vala >>> 2 &&& 1) * 2, :pl_i2cy2)
    HmiWorker.pl((vala >>> 3 &&& 1) * 2, :pl_i2cy3)
    HmiWorker.pl((vala >>> 4 &&& 1) * 2, :pl_i2cy4)
    HmiWorker.pl((vala >>> 5 &&& 1) * 2, :pl_i2cy5)
    HmiWorker.pl((vala >>> 6 &&& 1) * 2, :pl_i2cy6)
    HmiWorker.pl((vala >>> 7 &&& 1) * 2, :pl_i2cy7)
    # 起動状態
    HmiWorker.pl(Rs.Auto.stateget(), :pl_run)
    # 移動先ポジション
    case {Worker.check(:toggle)} do
      {0} ->
        HmiWorker.pl(3, :pl_pos1)
        HmiWorker.pl(0, :pl_pos2)

      {_} ->
        HmiWorker.pl(0, :pl_pos1)
        HmiWorker.pl(3, :pl_pos2)
    end
  end

  @doc """
  原点復帰
  """
  def act(:genten) do
    # 原点信号のチェック
    case {r(@reg_xorgdone)} do
      # 原点復帰開始
      {0} -> wp(@reg_yorigin)
      # 原点にあればそれ以上しない
      {_} -> Logger.warn("#{__MODULE__} genten: ok")
    end
  end

  @doc """
  ポジション指定
  ## Parameter
    - val:ポジション番号（0-7）
  """
  def setpos(val) do
    # 範囲の確認
    if 0 <= val && val <= 7 do
      # 範囲内なら
      # ビットにバラして順次転送
      w(val &&& 1, @reg_ysetpos1)
      w(val >>> 1 &&& 1, @reg_ysetpos2)
      w(val >>> 2 &&& 1, @reg_ysetpos4)
      Logger.info("* #{__MODULE__}: SET Position")
    else
      # 範囲外ならエラー
      raise ArgumentError, message: "the argument value is invalid"
    end
  end

  @doc """
  移動開始
  """
  def act(:start) do
    # 信号のチェック：原点、移動中、アラーム
    case {r(@reg_xorgdone), r(@reg_xmove), r(@reg_xalarm)} do
      # 移動開始
      {1, 0, 1} ->
        wp(@reg_ystart)
        Logger.info("* #{__MODULE__}: ACT START")

      # 条件が揃ってないとき
      {_, _, _} ->
        raise "Can't start"
    end
  end

  @doc """
  位置指定付きの移動開始
  """
  def act(val, :start) do
    # 位置指定
    setpos(val)
    # スタート
    act(:start)
  end

  @doc """
  リセット
  """
  def act(:reset) do
    # リセット
    wp(@reg_yreset)
    Logger.info("* #{__MODULE__}: ACT RESET")
  end

  @doc """
  アラームチェック
  """
  def check(:alarm) do
    r(@reg_xalarm)
  end

  @doc """
  移動中チェック
  """
  def check(:move) do
    r(@reg_xmove)
  end

  @doc """
  到着位置チェック
  """
  def check(:pos) do
    r(@reg_xgetpos1)
    +r(@reg_xgetpos2) * 10
    +r(@reg_xgetpos4) * 100
  end
end
