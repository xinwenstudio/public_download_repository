#!/bin/bash

set -e

# 颜色打印
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# 检查参数
if [[ "$1" != "-f" || -z "$2" ]]; then
    error "用法: $0 -f <配置文件路径>"
    exit 1
fi

CONFIG_FILE="$2"
HOSTNAME=$(hostname)

info "读取配置文件: $CONFIG_FILE"
info "当前主机名: $HOSTNAME"

# 提取主机配置段
SECTION_FOUND=0
declare -A IFACES
GATEWAY=""
DNS=""
NETMASK=""

while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')  # 去除首尾空格
    [[ -z "$line" || "$line" =~ ^# ]] && continue         # 跳过空行和注释

    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
        CURRENT_SECTION="${BASH_REMATCH[1]}"
        if [[ "$CURRENT_SECTION" == "$HOSTNAME" ]]; then
            SECTION_FOUND=1
        else
            SECTION_FOUND=0
        fi
        continue
    fi

    if [[ "$SECTION_FOUND" -eq 1 ]]; then
        KEY=$(echo "$line" | cut -d= -f1 | xargs)
        VALUE=$(echo "$line" | cut -d= -f2- | xargs)

        if [[ "$KEY" =~ ^ens[0-9]+$ ]]; then
            IFACES["$KEY"]="$VALUE"
        elif [[ "$KEY" == "gateway" ]]; then
            GATEWAY="$VALUE"
        elif [[ "$KEY" == "dns" ]]; then
            DNS="$VALUE"
        elif [[ "$KEY" == "netmask" ]]; then
            NETMASK="$VALUE"
        fi
    fi
done < "$CONFIG_FILE"

if [[ ${#IFACES[@]} -eq 0 ]]; then
    error "未找到主机 [$HOSTNAME] 的接口配置！"
    exit 1
fi

# 配置网卡
for IFACE in "${!IFACES[@]}"; do
    IP=${IFACES[$IFACE]}
    info "配置 $IFACE: IP=$IP, Netmask=$NETMASK, Gateway=$GATEWAY, DNS=$DNS"

    nmcli con mod "$IFACE" ipv4.addresses "$IP/$NETMASK"
    nmcli con mod "$IFACE" ipv4.gateway "$GATEWAY"
    nmcli con mod "$IFACE" ipv4.dns "$DNS"
    nmcli con mod "$IFACE" ipv4.method manual

    # 重新连接接口
    info "重启网络接口 $IFACE"
    nmcli con down "$IFACE" || true
    nmcli con up "$IFACE"
done

info "网络配置完成！"

