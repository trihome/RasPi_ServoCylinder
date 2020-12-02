defmodule Hmi.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  alias Scenic.ViewPort

  import Scenic.Primitives
  import Scenic.Components
  alias Scenic.Sensor

  # --------------------------------------------------------
  # コントロール配置

  # 基本フォントサイズ
  @text_size 24

  # 見出し
  @header [
    text_spec("ROBO Cylinder Console", t: {20, 40}, font_size: 30),
    text_spec("KOCHI.ex", t: {500, 45}, font_size: 15),
    line_spec({{10, 50}, {650, 50}}, stroke: {4, :cyan}, cap: :round)
  ]

  # ランプ列（入力）
  @pl_i2cinput [
    rectangle_spec({270, 70}, fill: :black, stroke: {2, :white}, t: {0, 0}),
    text_spec("I2C Input", t: {20, 30}),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {30, 50}, id: :pl_i2cx0),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {60, 50}, id: :pl_i2cx1),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {90, 50}, id: :pl_i2cx2),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {120, 50}, id: :pl_i2cx3),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {150, 50}, id: :pl_i2cx4),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {180, 50}, id: :pl_i2cx5),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {210, 50}, id: :pl_i2cx6),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {240, 50}, id: :pl_i2cx7)
  ]

  # ランプ列（出力）
  @pl_i2coutput [
    rectangle_spec({270, 70}, fill: :black, stroke: {2, :white}, t: {0, 0}),
    text_spec("I2C Output", t: {20, 30}),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {30, 50}, id: :pl_i2cy0),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {60, 50}, id: :pl_i2cy1),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {90, 50}, id: :pl_i2cy2),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {120, 50}, id: :pl_i2cy3),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {150, 50}, id: :pl_i2cy4),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {180, 50}, id: :pl_i2cy5),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {210, 50}, id: :pl_i2cy6),
    circle_spec(12, fill: :grey, stroke: {3, :white}, t: {240, 50}, id: :pl_i2cy7)
  ]

  # 制御用ボタン
  @pb_control [
    button_spec("ORIGIN", id: :btn_origin, t: {20, 0}, width: 120, theme: :primary),
    button_spec("START", id: :btn_start, t: {20, 70}, width: 120, theme: :success),
    button_spec("CYCLE STOP", id: :btn_stop, t: {20, 120}, width: 120, theme: :warning),
    # 文字付きランプ
    rounded_rectangle_spec({50, 50, 10},
      fill: :grey,
      stroke: {2, :white},
      t: {160, 90},
      id: :pl_run
    ),
    text_spec("RUN", t: {165, 123}),
    rounded_rectangle_spec({50, 20, 10},
      fill: :grey,
      stroke: {2, :white},
      t: {220, 90},
      id: :pl_pos1
    ),
    text_spec("POS 1", t: {230, 105}, font_size: @text_size * 0.6),
    rounded_rectangle_spec({50, 20, 10},
      fill: :grey,
      stroke: {2, :white},
      t: {220, 120},
      id: :pl_pos2
    ),
    text_spec("POS 2", t: {230, 135}, font_size: @text_size * 0.6)
  ]

  # 画面構成
  @graph Graph.build(font: :roboto, font_size: @text_size)
         |> add_specs_to_graph(
           [
             group_spec(@header, t: {0, 0}),
             group_spec(@pb_control, t: {0, 80}),
             group_spec(@pl_i2cinput, t: {300, 80}),
             group_spec(@pl_i2coutput, t: {300, 160})
           ],
           t: {10, 10}
         )

  @doc """
  コールバック関数：メッセージ受信
  """
  def init(_, opts) do
    # get the width and height of the viewport. This is to demonstrate creating
    # a transparent full-screen rectangle to catch user input
    {:ok, %ViewPort.Status{size: {_width, _height}}} = ViewPort.info(opts[:viewport])

    # show the version of scenic and the glfw driver
    _scenic_ver = Application.spec(:scenic, :vsn) |> to_string()
    _glfw_ver = Application.spec(:scenic, :vsn) |> to_string()

    # Sensorの受信許可
    Sensor.subscribe(:message_lamp)

    {:ok, @graph, push: @graph}
  end

  @doc """
  コールバック関数：Sensorの受信
  """
  def handle_info({:sensor, :data, {:message_lamp, {id, val}, _}}, graph) do
    graph =
      case {val} do
        # ランプを黄色く点灯
        {1} -> Graph.modify(graph, id, &update_opts(&1, fill: :lime))
        # ランプを黄色く点灯
        {2} -> Graph.modify(graph, id, &update_opts(&1, fill: :yellow))
        # ランプをオレンジ点灯
        {3} -> Graph.modify(graph, id, &update_opts(&1, fill: :peru))
        # ランプを灰色に消灯
        {_} -> Graph.modify(graph, id, &update_opts(&1, fill: :grey))
      end

    Logger.debug("#{__MODULE__} / Received event: id #{id} / #{val}")
    {:noreply, graph, push: graph}
  end

  @doc """
  コールバック関数：キー・マウスイベント受信
  """
  def handle_input(event, _context, state) do
    Logger.info("Received event: #{inspect(event)}")
    {:noreply, state}
  end

  @doc """
  クリックイベントの受付
  """
  def filter_event(event, _, graph) do
    graph =
      case event do
        # STARTボタン
        {:click, :btn_start} ->
          Rs.Auto.statenew(1)
          # 書き換え無し
          graph

        # STOPボタン
        {:click, :btn_stop} ->
          Rs.Auto.statenew(0)
          # 書き換え無し
          graph

        # ORIGINボタン
        {:click, :btn_origin} ->
          Rs.Worker.act(:genten)
          # 書き換え無し
          graph

        # それ以外
        {_, _} ->
          # 書き換え無し
          graph
      end

    # イベント内容を表示
    Logger.info("Received event: #{inspect(event)}")

    {:cont, event, graph, push: graph}
  end
end
