#!/bin/bash

# 进程名
process="./hysteria"

# 获取进程ID
PID=$(ps -ef | grep $process | grep -v grep | awk '{print $2}')

if [ -n "$PID" ]; then
    if ps -p $PID >/dev/null; then
        echo "正在停止 Hysteria..."
	kill -9 $PID
    fi
else
    echo "Hysteria 已停止工作"
fi
echo "正在启动 Hysteria..."
nohup ./hysteria > hysteria.log &
