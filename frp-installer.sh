#!/bin/bash
CYAN="\e[36m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
NC="\e[0m"

# Function to continue after pressing Enter
press_enter() {
    echo -e "\n ${RED}Press Enter to continue... ${NC}"
    read
}

uninstall_frp() {
    echo -e "${YELLOW}Uninstalling FRP...${NC}"

    # Stop and remove FRP Docker containers
    if [ -d "./frpc" ]; then
        docker-compose -f "./frpc/docker-compose.yml" down
    else
        echo -e "${RED}FRP client directory does not exist.${NC}"
    fi

    # Remove FRP directory
    rm -rf "./frp_0.51.3_linux_amd64"

    echo -e "${GREEN}FRP has been uninstalled.${NC}"
}

# Function to display FRP configuration
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
}

# Check if script is being run as root
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
    echo -e "${YELLOW}______________________________________________________${NC}"
    echo -e ""
    echo -e "                 ${MAGENTA}${title_text}${NC}"
    echo -e ""
    echo -e "${BLUE}$tg_title ${NC}"
    echo -e "${BLUE}$yt_title  ${NC}"
    echo -e "${YELLOW}______________________________________________________${NC}"
    echo ""
    echo ""
    echo -e "${RED}1. ${CYAN}Configure FRP - (Kharej) or server${NC}"
    echo -e "${RED}2. ${CYAN}Configure FRP - (Iran) or client${NC}"
    echo -e "${RED}3. ${CYAN}Uninstall FRP - client or server${NC}"
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
 echo ""
    echo -e "${YELLOW}Docker is not installed. Installing Docker now..."
    apt-get install -y docker &> /dev/null
    apt-get install -y docker-compose &> /dev/null
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
    sudo rm -rf "./frps" && mkdir -p "./frps/tmp"
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
 
echo -e "${YELLOW}Starting FRP server...${NC}"
docker-compose -f "./frps/docker-compose.yml" up -d

# Sleep for a few seconds to allow the containers to start
sleep 3

if [ -f "./frps/tmp/frps.log" ]; then
    echo -e "${GREEN}FRP server started successfully.${NC}"
    sudo cat "./frps/tmp/frps.log"
else
    echo -e "${RED}Error: FRP server failed to start. Log file not found.${NC}"
fi

echo -e "\033[1;32mServer IP Address:\033[0m $(curl -s ifconfig.co)"
echo -e "\033[1;32mService Port:\033[0m $port"
echo -e "\033[1;32mToken:\033[0m $token"
echo -e "\033[1;32mHTTP Port:\033[0m $http"
echo -e "\033[1;32mHTTPS Port:\033[0m $https"
press_enter
            ;;

        2)
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Installing Docker now..."
    curl -O https://kingtam.win/usr/uploads/script/install-docker.sh && chmod +x install-docker.sh && ./install-docker.sh
fi
read -p "Enter the FRP(S) Server ip address or domain: " frpsip
read -p "Enter the FRP(S) Service port (press Enter for default **7000** or manual to input a port): " port
if [ -z "$port" ]
then
    port=7000
else
    read -p "Enter the FRP(S) Service port: " port
fi
 
read -p "Enter the FRP(S) Service token: " token
 
read -p "Enter the port of FRP(C) admin console (press Enter for default **7400** or manual to input a port): " cport
if [ -z "$cport" ]
then
    cport=7400
else
    read -p "Enter the FRP(C) admin console port: " cport
fi
 
read -p "Enter the username of FRP(C) console (press Enter for default **admin** or manual to input a name): " cname
if [ -z "$cname" ]
then
    cname=admin
else
    read -p "Enter the username of FRP(C) console: " cname
fi
 
echo "Would you like to generate a Random Console Password (Press Enter) or enter a password for the FRP(C) console?"
read cpasswd
 
if  -z $cpasswd ; then
    ctoken=$(openssl rand -hex 12)
else
    ctoken=$cpasswd
fi
if [ ! -d "./frpc/tmp" ]; then
    mkdir -p ./frpc/tmp
else
    sudo rm -rf ./frpc && mkdir -p ./frpc/tmp
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
 
echo -e "Please use below information to Login console and setup your FRP(C) services"
echo -e "The address of console: \033[1;32mhttp://localhost:$cport\033[0m"
echo -e "The username of console: \033[1;32m$cname\033[0m"
echo -e "The password of console: \033[1;32m$ctoken\033[0m"
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
            # Exit the script
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a valid option.${NC}"
            ;;
    esac
done
