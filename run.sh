#!/bin/bash
# 起動スクリプト
# 2020 myasu

#ラズパイ本体に直結のディスプレイに、Scenic(HMI)の画面を出力
export DISPLAY=:0.0
#起動（iexを起動したあと、superviserがplcとhmiをそれぞれ起動）
iex -S mix
#終了後、シグナルタワーが点灯していたら全て消す
gpio -g write 6 0 ; gpio -g write 13 0 ; gpio -g write 19 0 ; gpio -g write 26 0
