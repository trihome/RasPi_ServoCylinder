defmodule Rs.Auto do
  @moduledoc """
  Documentation for `AutoRs`.
  機能：ロボシリンダの自動運転
  """

  use GenServer
  use Timex
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

    # 再帰呼び出しで起動
    Task.async(Rs.Auto, :schedule_work1, [0, 0, 0])
    {:ok, state}
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
  def terminate(reason, _state) do
    Logger.debug("#{__MODULE__} terminate: #{inspect(reason)}")
    reason
  end

  def statenew(val, pname \\ :autors), do: GenServer.call(pname, {:statenew, val})

  @doc """
  コールバック関数：stateの変更
  """
  @impl GenServer
  def handle_call({:statenew, newstate}, _from, state) do
    IO.puts(" > Current: #{state}")
    state = newstate
    IO.puts(" > New: #{state}")
    {:reply, newstate, state}
  end

  def stateget(pname \\ :autors), do: GenServer.call(pname, :stateget)

  @doc """
  コールバック関数：stateの参照
  """
  @impl GenServer
  def handle_call(:stateget, _from, state) do
    {:reply, state, state}
  end

  @doc """
  一定時間毎に実行
  """
  def schedule_work1(kidou, sequence, timer1) do
    # ---------------------------------
    # 入力更新

    # 起動ボタン受付
    kidou =
      case {Worker.state(kidou, :kidou), Rs.Auto.stateget()} do
        # PB起動
        {1, _} -> 1
        # Scenicボタン起動
        {_, 1} -> 1
        # それ以外
        {_, _} -> 0
      end

    # リセットボタン受付
    case {Worker.check(:reset)} do
      {1} -> Rs.Worker.act(:reset)
      {_} -> 0
    end

    # 位置決めポジションチェック
    pos_to =
      case {Worker.check(:toggle)} do
        {0} -> 1
        {_} -> 3
      end

    # ---------------------------------
    # 自動シーケンス
    sequence =
      case {sequence} do
        {0} ->
          # 起動状態チェック
          case {kidou} do
            {1} ->
              Logger.info("* #{__MODULE__}: 起動")
              1

            {_} ->
              0
          end

        {1} ->
          # 運転開始
          Rs.Worker.act(pos_to, :start)
          Logger.info("* #{__MODULE__}: 移動開始 -> Position #{pos_to}")
          2

        {2} ->
          # 到着待ち
          case {Rs.Worker.check(:move)} do
            {0} ->
              # 到着した
              3

            {_} ->
              # 到着してない
              Logger.info("* #{__MODULE__}: 移動中")
              2
          end

        {3} ->
          # 表示
          Logger.info("* #{__MODULE__}: 作動側着")
          4

        {4} ->
          # 待機
          Logger.info("* #{__MODULE__}: 待機開始")
          5

        {5} ->
          # 待機
          # 現在時刻読み込み、直前のシーケンスの値と比較
          time = Timex.diff(Timex.local(), timer1, :millisecond)
          Logger.info("* #{__MODULE__}: 待機中 -> #{time} ms")

          case {time} do
            # 指定時間を超えたら次へ
            {x} when x > 1000 -> 6
            {_} -> 5
          end

        {6} ->
          # 運転開始（戻り）
          Rs.Worker.act(0, :start)
          Logger.info("* #{__MODULE__}: 移動開始 -> Position 0")
          7

        {7} ->
          # 到着待ち
          case {Rs.Worker.check(:move)} do
            {0} ->
              # 到着した
              8

            {_} ->
              # 到着してない
              Logger.info("* #{__MODULE__}: 移動中")
              7
          end

        {8} ->
          # 表示
          Logger.info("* #{__MODULE__}: 復帰側着")
          9

        {9} ->
          # 起動を落とす
          Logger.info("* #{__MODULE__}: 停止")
          10

        {_} ->
          0
      end

    Logger.debug("* #{__MODULE__}: シーケンス番号 #{sequence},  起動状態 #{kidou}")

    # ---------------------------------
    # 再帰変数更新

    # タイマー更新
    timer1 =
      if sequence == 4 do
        Timex.local()
      else
        timer1
      end

    # IO.inspect(timer1)

    # 起動を落とす
    kidou =
      if sequence == 9 do
        0
      else
        kidou
      end

    # ---------------------------------
    # 出力更新

    # HMI更新
    Rs.Worker.getstate(:hmi)

    # 起動ランプ
    case {kidou} do
      {1} ->
        Gpio.write(true, :out_sigt_g)

      {_} ->
        Gpio.write(false, :out_sigt_g)
    end

    # 注意ランプ
    case {sequence} do
      {2} ->
        Gpio.write(true, :out_sigt_y)

      {7} ->
        Gpio.write(true, :out_sigt_y)

      {_} ->
        Gpio.write(false, :out_sigt_y)
    end

    # アラームチェック
    case {Rs.Worker.check(:alarm)} do
      {0} ->
        # アラーム中なら赤点灯
        Gpio.write(true, :out_sigt_r)
        Gpio.write(true, :out_plpb_r)

      {_} ->
        # でなければ消灯
        Gpio.write(false, :out_sigt_r)
        Gpio.write(false, :out_plpb_r)
    end

    # 待機
    Process.sleep(Application.fetch_env!(:plc, :auto_interval))
    # 再帰呼び出し
    schedule_work1(kidou, sequence, timer1)
  end
end
