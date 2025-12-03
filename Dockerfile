# 使用 Ubuntu 22.04 基础镜像
FROM ubuntu:22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8

# 配置 i386 架构并添加 WineHQ 源、安装所需依赖和工具，清理缓存
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common wget curl supervisor x11vnc xvfb xterm xfce4 xfce4-terminal \
        python3 ca-certificates locales locales-all fonts-wqy-zenhei fonts-wqy-microhei \
        fonts-noto-cjk fonts-noto-cjk-extra fonts-noto-color-emoji && \
    . /etc/os-release && CODENAME=${UBUNTU_CODENAME:-${VERSION_CODENAME}} && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -q -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/${CODENAME}/winehq-${CODENAME}.sources && \
    apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    # 设置中文locale\n    locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 安装 winetricks
RUN wget -q -O /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/bin/winetricks

# 配置wine的中文环境变量
ENV WINEARCH=win64 \
    WINEPREFIX=~/.wine \
    WINEDEBUG=-all

# 复制并执行下载 Gecko 和 Mono 的脚本
COPY download_gecko_and_mono.sh /root/download_gecko_and_mono.sh
RUN chmod +x /root/download_gecko_and_mono.sh && \
    # 使用 apt-cache 而不是直接运行 wine 获取版本号
    WINE_VERSION=$(apt-cache policy winehq-stable | grep -oP 'Installed: \K[^\s]+' | sed -E 's/^[0-9]:([0-9]+\.[0-9]+\.[0-9]+).*/\1/') && \
    echo "Detected Wine version: $WINE_VERSION" && \
    /root/download_gecko_and_mono.sh "$WINE_VERSION" && \
    rm -f /root/download_gecko_and_mono.sh

# 安装 noVNC 和 websockify，设置 noVNC 的默认页面
RUN mkdir -p /opt/novnc/utils/websockify && \
    curl -sL https://github.com/novnc/noVNC/archive/v1.5.0.tar.gz | tar xz -C /opt/novnc --strip-components=1 && \
    curl -sL https://github.com/novnc/websockify/archive/v0.12.0.tar.gz | tar xz -C /opt/novnc/utils/websockify --strip-components=1 && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# 创建 supervisor 配置目录和日志目录并复制独立配置文件
RUN mkdir -p /etc/supervisor/conf.d /var/log/supervisord
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor/conf.d/* /etc/supervisor/conf.d/

# 添加启动脚本
COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

# 暴露端口
EXPOSE ${VNC_PORT} ${NOVNC_PORT}

# 创建应用挂载目录并设置权限
RUN mkdir -p /app && chmod -R 755 /app

# 设置默认工作目录
WORKDIR /app

# 使用启动脚本启动服务
ENTRYPOINT ["/opt/startup.sh"]