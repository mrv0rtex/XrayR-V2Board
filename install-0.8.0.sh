#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/XrayR-project/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to detect XrayR version, it may be that the Github API limit is exceeded, please try again later, or manually specify the XrayR version to install${plain}"
            exit 1
        fi
        echo -e "XrayR latest version detected：${last_version}，start installation"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/XrayR-project/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download XrayR, please make sure your server can download Github files${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/XrayR-project/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip"
        echo -e "Start installing XrayR ${last_version}"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux-64.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download XrayR ${last_version} failed, make sure this version exists${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux-64.zip
    rm XrayR-linux-64.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://github.com/missuo/XrayR-V2Board/raw/main/XrayR.service"
    wget -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    #cp -f XrayR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} The installation is complete, it has been set to start automatically"
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "New installation, please refer to the tutorial first：https://github.com/XrayR-project/XrayR，Configure the necessary content"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
         echo -e "${green}XrayR restarted successfully ${plain}"
        else
            echo -e "${red}XrayR may fail to start, please use XrayR log to check the log information later, if it fails to start, the configuration format may have been changed, please go to the wiki to check：https://github.com/XrayR-project/XrayR/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/missuo/XrayR-V2Board/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    
    # 设置节点序号
    echo "Set the node number"
    echo ""
    read -p "Please enter the node number in V2Board:" node_id
    [ -z "${node_id}" ]
    echo "---------------------------"
    echo "The node number you set is ${node_id}"
    echo "---------------------------"
    echo ""

    # 选择协议
    echo "Select node type (default V2ray)"
    echo ""
    read -p "Please enter the protocol you are using (V2ray, Shadowsocks, Trojan):" node_type
    [ -z "${node_type}" ]
    
    # 如果不输入默认为V2ray
    if [ ! $node_type ]; then 
    node_type="V2ray"
    fi

    echo "---------------------------"
    echo "The protocol you selected is ${node_type}"
    echo "---------------------------"
    echo ""
    
    # 关闭AEAD强制加密
    # echo "选择是否关闭AEAD强制加密(默认开启AEAD)"
    # echo ""
    # read -p "请输入您的选择(1为开启,0为关闭):" aead_disable
    # [ -z "${aead_disable}" ]
   

    # # 如果不输入默认为开启
    # if [ ! $aead_disable ]; then
    # aead_disable="1"
    # fi

    # echo "---------------------------"
    # echo "您的设置为 ${aead_disable}"
    # echo "---------------------------"
    # echo ""

    # Writing json
    echo "正在尝试写入配置文件..."
    wget https://cdn.jsdelivr.net/gh/missuo/XrayR-V2Board/config.yml -O /etc/XrayR/config.yml
    sed -i "s/NodeID:.*/NodeID: ${node_id}/g" /etc/XrayR/config.yml
    sed -i "s/NodeType:.*/NodeType: ${node_type}/g" /etc/XrayR/config.yml
    echo ""
    echo "写入完成，正在尝试重启XrayR服务..."
    echo
    
    # if [ $aead_disable == "0" ]; then
    # echo "正在关闭AEAD强制加密..."
    # sed -i 'N;18 i Environment="XRAY_VMESS_AEAD_FORCED=false"' /etc/systemd/system/XrayR.service
    # fi

    systemctl daemon-reload
    XrayR restart
    echo "Turning off firewall!"
    echo
    systemctl disable firewalld
    systemctl stop firewalld
    echo "XrayR service has been restarted, please enjoy！"
    echo
    #curl -o /usr/bin/XrayR-tool -Ls https://raw.githubusercontent.com/missuo/XrayR/master/XrayR-tool
    #chmod +x /usr/bin/XrayR-tool
    echo -e ""
    echo "XrayR How to use the management script (compatible with xrayr execution, case insensitive): "
    echo "------------------------------------------"
    echo "XrayR                    - Show management menu (more functions)"
    echo "XrayR start              - Start XrayR"
    echo "XrayR stop               - Stop XrayR"
    echo "XrayR restart            - XrayR restart"
    echo "XrayR status             - XrayR status"
    echo "XrayR enable             - XrayR enable"
    echo "XrayR disable            - XrayR disable "
    echo "XrayR log                - XrayR log"
    echo "XrayR update             - XrayR update"
    echo "XrayR update x.x.x       - Update XrayR specified version"
    echo "XrayR config             - XrayR config"
    echo "XrayR install            - XrayR install"
    echo "XrayR uninstall          - XrayR uninstall"
    echo "XrayR version            - XrayR version"
    echo "------------------------------------------"
    echo "One-Step Script Based on XrayR-Release"
    echo "Telegram: https://t.me/mrvortex"
    echo "Github: https://github.com/missuo/XrayR-V2Board"
    echo "Powered by Vincent"
}

echo -e "${green}start installation${plain}"
install_base
install_acme
install_XrayR $1
