#!/bin/bash

# 设置Wine的中文环境变量
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export WINEDEBUG=-all
export WINEARCH=win64
export WINEPREFIX=~/.wine

VNC_PASSWD_FILE="/root/.vnc/passwd"

# 初始化wine环境并配置中文支持
if [ ! -d "$WINEPREFIX" ]; then
    echo "初始化Wine环境..."
    wineboot --init
    winetricks -q settings locale zh-CN
fi

# 如果传入了 VNC_PASSWD 环境变量，则更新密码
if [[ -n "$VNC_PASSWD" ]]; then
    echo "Custom VNC password provided. Updating password..."
    mkdir -p /root/.vnc
    x11vnc -storepasswd "$VNC_PASSWD" "$VNC_PASSWD_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to set custom VNC password."
        exit 1
    fi

# 如果没有传入 VNC_PASSWD 且没有现有密码文件，则生成随机密码
elif [[ ! -f "$VNC_PASSWD_FILE" ]]; then
    echo "No VNC password provided and no existing password file found. Generating a random password..."
    VNC_PASSWD=$(openssl rand -base64 12)  # 生成随机密码
    echo "Generated VNC password: $VNC_PASSWD"
    mkdir -p /root/.vnc
    x11vnc -storepasswd "$VNC_PASSWD" "$VNC_PASSWD_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to set generated VNC password."
        exit 1
    fi
else
    echo "Using existing VNC password file."
fi

# 启动 Supervisor 并输出日志路径
echo "Starting supervisord to manage services..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
