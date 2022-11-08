#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}wrong：${plain} This script must be run as root user! \n" && exit 1

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
    echo -e "${red}
System version not detected，Please contact the script author！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}Failed to detect schema，Use default schema: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software does not support 32-bit systems (x86)，
Please use a 64-bit system (x86_64)，
If the detection is wrong, please contact the author"
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
        echo -e "${red}
Please use CentOS 7 or higher！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
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
        if [[ $1 == v* ]]; then
            last_version=$1
	else
	    last_version="v"$1
	fi
        url="https://github.com/XrayR-project/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip"
        echo -e "Start installing XrayR ${last_version}"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download XrayR ${last_version} failed, make sure this version exists${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://github.com/XrayR-project/XrayR-release/raw/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
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
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cp route.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/rulelist ]]; then
        cp rulelist /etc/XrayR/
    fi

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

    # 写入配置文件
    echo "Trying to write configuration file..."
    wget https://github.com/mrv0rtex/XrayR-V2Board/blob/main/config.yml -O /etc/XrayR/config.yml
    sed -i "s/NodeID:.*/NodeID: ${node_id}/g" /etc/XrayR/config.yml
    sed -i "s/NodeType:.*/NodeType: ${node_type}/g" /etc/XrayR/config.yml
    echo ""
    echo "Writing completed, trying to restart XrayR service..."
    echo


    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr # 小写兼容
    chmod +x /usr/bin/xrayr

    systemctl daemon-reload
    XrayR restart
    echo "Turning off firewall!"
    echo
    systemctl disable firewalld
    systemctl stop firewalld
    echo "XrayR service has been restarted, please enjoy！"
    echo

    cd $cur_dir
    rm -f install.sh
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
    echo "Telegram: https://t.me/missuo"
    echo "Github: https://github.com/missuo/XrayR-V2Board"
    echo "Powered by Vincent"
}

echo -e "${green}start installation${plain}"
install_base
# install_acme
install_XrayR $1
