#!/bin/bash
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@    作者： 工作室里头叫ljx的          
#@    最后编辑时间： 25/6/1
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# 检查是否安装 sshpass
rpm -qa | grep -qw sshpass
if [ $? -ne 0 ]; then
    echo "没有安装 sshpass，正在安装..."
    dnf install -y sshpass
else
    echo "已安装 sshpass"
fi

# 使用说明
usage_help(){
    echo "Usage: $0 [-l local_user] [-u remote_user] <Destination IP>"
    echo "Example: $0 -l www-data -u root 192.168.1.10"
    exit 1
}

# 参数解析
while getopts "l:u:h" opt; do
    case $opt in
        l) local_user="$OPTARG" ;;
        u) remote_user="$OPTARG" ;;
        h) usage_help ;;
        *) usage_help ;;
    esac
done
shift $((OPTIND - 1))
# 设置密钥目录，判断有无参数传入
if [ -n "$local_user" ]; then
    LOCAL_HOME=$(eval echo "~$local_user")
    KEY_DIR="$LOCAL_HOME/.ssh"
    if [ ! -f "$host_file" ]; then
        sudo -u "$local_user" mkdir -p "$LOCAL_HOME/.ssh"
        sudo chown "$local_user:$local_user" "$LOCAL_HOME/.ssh"
        sudo chmod 700 "$LOCAL_HOME/.ssh"
    fi
else
    KEY_DIR="$HOME/.ssh"
fi
sleep 1
echo "==========================================="
echo "local_user: $local_user, KEY_DIR: $KEY_DIR"
echo "==========================================="
# 功能菜单
echo "+=============================================================+"
echo "| 请选择功能:                                                 |"
echo "| 1. 单主机配置免密登录                                       |"
echo "| 2. 多主机配置免密登录                                       |"
echo "| 3. 从文件批量配置免密登录（需 sshpass）                      |"
echo "| 4. 固定用户名和密码批量配置免密登录（需 sshpass）            |"
echo "+=============================================================+"
read -p "输入选项 (1|2|3|4): " num1

# 初始化
remote_hosts=()
remote_users=()
remote_passes=()
exit_code=()

case "$num1" in
    1)
        read -p "输入主机地址: " remote_host
        ping -c 1 -W 1 "$remote_host" > /dev/null || { echo "无法连接 $remote_host"; exit 1; }
        remote_hosts+=("$remote_host")
        read -p "输入远程用户名: " ru
        remote_users+=("$ru")
        read -s -p "输入远程密码: " rp; echo
        remote_passes+=("$rp")
        ;;
    2)
        read -p "输入主机数量: " dev_num
        for ((i=1; i<=dev_num; i++)); do
            read -p "输入第 $i 台主机地址: " host
            ping -c 1 -W 1 "$host" > /dev/null || { echo "无法连接 $host，跳过..."; continue; }
            read -p "输入用户名: " user
            read -s -p "输入密码: " pass; echo
            remote_hosts+=("$host")
            remote_users+=("$user")
            remote_passes+=("$pass")
        done
        ;;
    3)
        host_file=~/auto_ssh_host.txt
        [ ! -f "$host_file" ] && { echo "文件 $host_file 不存在"; exit 1; }
        while read -r host user pass; do
            ping -c 1 -W 1 "$host" > /dev/null || { echo "无法连接 $host，跳过..."; continue; }
            remote_hosts+=("$host")
            remote_users+=("$user")
            remote_passes+=("$pass")
        done < "$host_file"
        ;;
    4)
        if [ -n "$remote_user" ]; then
            host_user="$remote_user"
        else
            read -p "输入主机用户名: " host_user
        fi
        remote_users=("$host_user")

        if [ ${#remote_passes[@]} -eq 0 ]; then
            read -s -p "输入密码(不显示)" host_pass
            echo
            remote_passes=("$host_pass")
        fi
        echo "1. 从文件读取IP"
        echo "2. 手动输入IP范围 (如 192.168.1.100-110)"
        echo "3. 退出程序"
        read -p "选择方式: " ipopt
        case "$ipopt" in
            1)
                host_file=~/auto_ssh_host.txt
                [ ! -f "$host_file" ] && { echo "文件 $host_file 不存在"; exit 1; }
                while read -r host _ _; do
                    ping -c 1 -W 1 "$host" > /dev/null || { echo "无法连接 $host，跳过..."; continue; }
                    remote_hosts+=("$host")
                done < "$host_file"
                ;;
            2)
                read -p "输入 IP 范围 (如 192.168.1.100-110): " ip_range
                [[ "$ip_range" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.([0-9]+)-([0-9]+)$ ]] || { echo "格式错误"; exit 1; }
                base=${BASH_REMATCH[1]}
                start=${BASH_REMATCH[2]}
                end=${BASH_REMATCH[3]}
                for ((i=start; i<=end; i++)); do
                    ip="$base.$i"
                    ping -c 1 -W 1 "$ip" > /dev/null || { echo "无法连接 $ip，跳过..."; continue; }
                    remote_hosts+=("$ip")
                done
                ;;
            3) exit 0 ;;
            *) echo "无效选项"; exit 1 ;;
        esac
        ;;
    *) echo "无效输入"; exit 1 ;;
esac

# 密钥处理选项
echo "1. 已有密钥，进行免密登录"
echo "2. 生成密钥，进行免密登录"
echo "3. 退出"
read -p "输入选项 (1|2|3): " keyopt

# 如果选择生成密钥
if [ "$keyopt" -eq 2 ]; then
    read -p "输入密钥密语（可留空）: " passphrase
    if [ -n "$local_user" ]; then
        sudo -u "$local_user" env HOME="$LOCAL_HOME" ssh-keygen -t rsa -b 4096 -f "$KEY_DIR/id_rsa" -N "$passphrase" -C "autossh"
    else
        ssh-keygen -t rsa -b 4096 -f "$KEY_DIR/id_rsa" -N "$passphrase" -C "autossh"
    fi
fi

# 确保密钥文件存在
[ ! -f "$KEY_DIR/id_rsa.pub" ] && { echo "找不到密钥文件 $KEY_DIR/id_rsa.pub，请先生成！"; exit 1; }

# 遍历主机执行 ssh-copy-id
for i in "${!remote_hosts[@]}"; do
    host="${remote_hosts[$i]}"
    if [ "$num1" -eq 4 ]; then
        user="${remote_users[0]}"
        password="${remote_passes[0]}"
    else
        user="${remote_users[$i]}"
        password="${remote_passes[$i]}"
    fi

    echo "正在配置 $user@$host ..."
    if [ -n "$local_user" ]; then
        sudo -u "$local_user" sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no -i "$KEY_DIR/id_rsa.pub" "$user@$host"
    else
        sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no -i "$KEY_DIR/id_rsa.pub" "$user@$host"
    fi

    if [ $? -eq 0 ]; then
        echo "成功复制密钥到 $user@$host"
        exit_code[$i]=1
        grep -q "$user@$host" "$KEY_DIR/host_list.txt" || echo "$user@$host" >> "$KEY_DIR/host_list.txt"
    else
        echo "复制密钥失败 $user@$host"
        exit_code[$i]=0
    fi
done

# 输出结果
echo "---------执行结果-------------"
echo -e "[\e[32mSUCCESS\e[0m]"
for i in "${!remote_hosts[@]}"; do
    [ "${exit_code[$i]}" -eq 1 ] && echo -e "\e[32m${remote_users[$i]}@${remote_hosts[$i]}\e[0m"
done
echo -e "[\e[31mERROR\e[0m]"
for i in "${!remote_hosts[@]}"; do
    [ "${exit_code[$i]}" -eq 0 ] && echo -e "\e[31m${remote_users[$i]}@${remote_hosts[$i]}\e[0m：请检查 用户权限、IP、用户名、密码、网络连接、SSH 服务状态"
done

