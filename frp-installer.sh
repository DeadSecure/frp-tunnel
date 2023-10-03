#!/bin/bash

CYAN="\e[36m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
NC="\e[0m"

press_enter() {
    echo -e "\n ${RED}Press Enter to continue... ${NC}"
    read
}

display_fancy_progress() {
    local duration=$1
    local sleep_interval=0.1
    local progress=0
    local bar_length=40

    while [ $progress -lt $duration ]; do
        echo -ne "\r[${YELLOW}"
        for ((i = 0; i < bar_length; i++)); do
            if [ $i -lt $((progress * bar_length / duration)) ]; then
                echo -ne "▓"
            else
                echo -ne "░"
            fi
        done
        echo -ne "${RED}] ${progress}%"
        progress=$((progress + 1))
        sleep $sleep_interval
    done
    echo -ne "\r[${YELLOW}"
    for ((i = 0; i < bar_length; i++)); do
        echo -ne "#"
    done
    echo -ne "${RED}] ${progress}%"
    echo
}

logo() {
    echo -e "\n${BLUE}
      ::::::::  ::::::::: ::::::::::: :::::::::      :::     ::::    ::: 
    :+:    :+: :+:    :+:    :+:     :+:    :+:   :+: :+:   :+:+:   :+:  
   +:+    +:+ +:+    +:+    +:+     +:+    +:+  +:+   +:+  :+:+:+  +:+   
  +#+    +:+ +#++:++#+     +#+     +#++:++#:  +#++:++#++: +#+ +:+ +#+    
 +#+    +#+ +#+           +#+     +#+    +#+ +#+     +#+ +#+  +#+#+#     
#+#    #+# #+#           #+#     #+#    #+# #+#     #+# #+#   #+#+#      
########  ###       ########### ###    ### ###     ### ###    ####       
    ${NC}\n"
}

if [ "$EUID" -ne 0 ]; then
    echo -e "\n ${RED}This script must be run as root.${NC}"
    exit 1
fi

uninstall_frp() {
    clear
    echo ""
    echo -e "${YELLOW}Uninstalling FRP service, please wait...${NC}"
    if docker ps -a --format '{{.Names}}' | grep -q "^frps$"; then
        docker stop frps
        docker rm frps
    fi
    if docker ps -a --format '{{.Names}}' | grep -q "^frpc$"; then
        docker stop frpc
        docker rm frpc
    fi
    rm -rf ./frpc
    docker rmi snowdreamtech/frpc:latest
    docker rmi snowdreamtech/frps:latest
    rm -f ./frps/frps.ini
    rm -f ./frpc/frpc.ini
    echo ""
    echo -e "${GREEN}FRP has been uninstalled.${NC}"
}

display_frp_config() {
    echo -e "${YELLOW}Displaying FRP Configuration...${NC}"
    if [ -f "./frps/frps.ini" ]; then
        echo -e "${GREEN}FRP Server Configuration:${NC}"
        cat "./frps/frps.ini"
    fi
    if [ -f "./frpc/frpc.ini" ]; then
        echo -e "${GREEN}FRP Client Configuration:${NC}"
        cat "./frpc/frpc.ini"
    fi

    if [ -f "./frpc/tmp/frpc.log" ]; then
        echo -e "${GREEN}FRP Client Log:${NC}"
        cat "./frpc/tmp/frpc.log"
    fi

    if [ -f "./frps/tmp/frps.log" ]; then
        echo -e "${GREEN}FRP Server Log:${NC}"
        cat "./frps/tmp/frps.log"
    fi
}

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

while true; do
clear
title_text="OPIran FRP Tunnel"
tg_title="TG-Group @OPIranCluB"
yt_title="youtube.com/@opiran-inistitute"
    clear
    echo -e "                 ${MAGENTA}${title_text}${NC}"
    echo -e "${YELLOW}______________________________________________________${NC}"
    logo
    echo -e "${BLUE}$tg_title ${NC}"
    echo -e "${BLUE}$yt_title  ${NC}"
    echo -e "${YELLOW}______________________________________________________${NC}"
    echo ""
    echo -e "${RED}1. ${CYAN}Configure FRP(s) - (Kharej) or server${NC}"
    echo -e "${RED}2. ${CYAN}Configure FRP(c) - (Iran) or client${NC}"
    echo -e "${RED}3. ${CYAN}Uninstall FRP - client and server${NC}"
    echo -e "${RED}4. ${CYAN}Display FRP Configuration${NC}"
    echo ""
    echo -e "${RED}0. ${CYAN}Exit${NC}"
    echo ""
    echo -ne "${YELLOW}Enter your choice: ${NC}"
    read choice
    case $choice in
        1)
if ! command -v docker &> /dev/null
then
clear
  title="Configure FRP server side"
    logo
    echo ""
    echo -e "${BLUE}$title ${NC}"
    echo ""
    echo -e "${YELLOW}______________________________________________________${NC}"
  echo ""
    echo -e "${YELLOW}Docker is not installed. Installing Docker now...${NC}"
    echo ""
    echo -e "${RED}Please wait, it might takes a while...${NC}"
    apt-get install docker -y > /dev/null 2>&1
    apt-get install docker-compose -y > /dev/null 2>&1
            display_fancy_progress 20
fi
echo ""
echo -ne "${YELLOW}Port for the frps service? ${RED}[Enter blank for default port : 7000] ${GREEN}[Enter 'r' to generate a random port] ${YELLOW}[or enter a port]: "
read port_choice
if [[ "$port_choice" == "r" ]]; then
    port=$(shuf -i 7001-9000 -n 1)
elif [[ -z "$port_choice" ]]; then
    port=7000
else
    port=$port_choice
fi
echo ""
echo -ne "${YELLOW}Port for the HTTP service? ${RED}[Press enter for default port of 80] ${YELLOW}[or enter a port]: "
read http_choice
if [[ -z "$http_choice" ]]; then
    http=80
else
    http=$http_choice
fi
echo ""
echo -ne "${YELLOW}Port for the HTTPS service? ${RED}[Press enter for default port of 443] ${YELLOW}[or enter a port]: "
read https_choice
if [[ -z "$https_choice" ]]; then
    https=443
else
    https=$https_choice
fi
echo ""
echo -ne "${YELLOW}Generate a random token or enter a password for the frps service? ${RED}[Press enter to generate a random token] ${YELLOW}or enter a password: "
read token_choice
if [[ -z "$token_choice" ]]; then
    token=$(openssl rand -hex 16)
else
    token=$token_choice
fi
if [ ! -d "./frps/tmp" ]; then
    mkdir -p "./frps/tmp"
else
    rm -rf "./frps" && mkdir -p "./frps/tmp"
fi
cat >> "./frps/frps.ini" << EOF
[common]
bind_addr = 0.0.0.0
bind_port = $port
vhost_http_port = $http
vhost_https_port = $https
dashboard_tls_mode = false
enable_prometheus = true
log_file = /tmp/frps.log
log_level = info
log_max_days = 3
disable_log_color = false
detailed_errors_to_client = true
authentication_method = token
authenticate_heartbeats = false
authenticate_new_work_conns = false
token = $token
max_pool_count = 5
max_ports_per_client = 0
tls_only = false
EOF
cat >> "./frps/docker-compose.yml" << EOF
version: '3'
services:
    frps:
        image: snowdreamtech/frps:latest
        container_name: frps
        network_mode: "host"
        restart: always
        volumes:
            - "$PWD/frps/frps.ini:/etc/frp/frps.ini"
            - "$PWD/frps/tmp:/tmp:rw"
EOF
echo ""
echo -e "${YELLOW}Starting FRP server...${NC}"
docker-compose -f "./frps/docker-compose.yml" up -d
sleep 3
if [ -f "./frps/tmp/frps.log" ]; then
    echo -e "${GREEN}FRP server started successfully.${NC}"
    sudo cat "./frps/tmp/frps.log"
else
    echo -e "${RED}Error: FRP server failed to start. Log file not found.${NC}"
fi
press_enter
clear
title="Configure FRP server side"
    logo
    echo ""
    echo -e "${BLUE}$title ${NC}"
    echo ""
    echo -e "${YELLOW}______________________________________________________${NC}"
  echo ""
echo -e "${MAGENTA}Please save below information to to use on your client server.${NC}"
echo ""
echo -e "${YELLOW}The address FRPS: ${GREEN}$(curl -s ifconfig.co)${NC}"
echo -e "${YELLOW}Service Port: ${GREEN}$port${NC}"
echo -e "${YELLOW}Token: ${GREEN}$token${NC}"
echo -e "${YELLOW}HTTP Port: ${GREEN}$http${NC}"
echo -e "${YELLOW}HTTPS Port: ${GREEN}$https${NC}"
echo ""
press_enter
            ;;
        2)
rm -rf /etc/resolv.conf
touch /etc/resolv.conf
echo 'nameserver 178.22.122.100' >> /etc/resolv.conf
echo 'nameserver 78.157.42.101' >> /etc/resolv.conf
if ! command -v docker &> /dev/null
then
clear
title="Configure FRP client side"
    logo
    echo ""
    echo -e "${BLUE}$title ${NC}"
    echo ""
    echo -e "${YELLOW}______________________________________________________${NC}"
  echo ""
    echo -e "${YELLOW}Docker is not installed. Installing Docker now...${NC}"
    echo ""
    echo -e "${RED}Please wait, it might takes a while...${NC}"
    rm -rf /etc/resolv.conf
    touch /etc/resolv.conf
    echo 'nameserver 178.22.122.100' >> /etc/resolv.conf
    echo 'nameserver 78.157.42.101' >> /etc/resolv.conf
    sleep 3
    secs=3
    while [ $secs -gt 0 ]; do
        echo -ne "Continuing in $secs seconds\033[0K\r"
        sleep 1
        : $((secs--))
    done
    apt-get install docker -y > /dev/null 2>&1
    apt-get install docker-compose -y > /dev/null 2>&1
            display_fancy_progress 20
fi
    echo -ne "\e[33mEnter the FRP(S) Server ip address or domain: ${NC}: "
    read frpsip
    echo ""
    echo -ne "\e[33mEnter the FRP(S) Service port ${RED}[Enter blank for default port : 7000]${YELLOW}[or enter a port]: ${NC} "
    read port
        if [[ -z "$port" ]]; then
        port=7000
        else
        port=$port
        fi
        echo ""
    echo -ne "${YELLOW}Enter the FRP(S) Service token:  ${NC}"
    read token
    echo ""
    echo -ne "${YELLOW}Enter the port of FRP(C) admin console ${RED}[press Enter for default **7400** or manual to input a port]: ${NC}"  
    read cport
        if [ -z "$cport" ]; then
            cport=7400
        else
            Cport=$Cport
        fi
        echo ""
    echo -ne "${YELLOW}Enter the username of FRP(C) console ${RED}[press Enter for default **admin** or manual to input a name]: ${NC}"  
    read cname
        if [ -z "$cname" ]; then
            cname=admin
        else
            cname=$cname
        fi
        echo ""
    echo -ne "${YELLOW}Enter the Console Password ${RED}[Press Enter for generate a random password] :  ${NC}"  
    read cpasswd
        if [ -z "$cpasswd" ]; then
            ctoken=$(openssl rand -hex 12)
        else
            ctoken=$cpasswd
        fi
        if [ ! -d "./frpc/tmp" ]; then
            mkdir -p ./frpc/tmp
        else
            rm -rf ./frpc && mkdir -p ./frpc/tmp
        fi
cat >> frpc/frpc.ini << EOF
[common]
server_addr = $frpsip
server_port = $port
token = $token
log_file = /tmp/frpc.log
log_level = info
log_max_days = 3
disable_log_color = false
admin_addr = 0.0.0.0
admin_port = $cport
admin_user = $cname
admin_pwd = $ctoken
EOF
cat >> frpc/docker-compose.yml << EOF
version: '3'
services:
    frpc:
        image: snowdreamtech/frpc:latest
        container_name: frpc
        network_mode: "host"
        restart: always
        volumes:
            - ./frpc.ini:/etc/frp/frpc.ini
            - ./tmp:/tmp:rw
EOF
docker-compose -f ./frpc/docker-compose.yml up -d
sleep 3
sudo cat ./frpc/tmp/frpc.log
press_enter
clear
rm -rf /etc/resolv.conf
touch /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
title="FRP Console Panel"
    logo
    echo ""
    echo -e "${BLUE}$title ${NC}"
    echo ""
    echo -e "${YELLOW}______________________________________________________${NC}"
  echo ""
echo -e "${MAGENTA}Please use below information to Login console to monitor your FRP(C) services.${NC}"
echo ""
echo -e "${YELLOW}The address of console: ${GREEN}http://$frpsip:$cport${NC}"
echo -e "${YELLOW}The username of console: ${GREEN}$cname${NC}"
echo -e "${YELLOW}The password of console: ${GREEN}$ctoken${NC}"
echo ""
press_enter
            ;;
        3)
        uninstall_frp
        press_enter
            ;;
        4)
        display_frp_config
        press_enter
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a valid option.${NC}"
            ;;
   esac
done
