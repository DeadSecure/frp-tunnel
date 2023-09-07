#!/bin/bash

echo -en "\033[37;1;41m Script for automatic configuration of IPv6 network settings. \033[0m \n\n\n"
echo -en "\033[37;1;41m Hosting VPS services - VPSVille.ru \033[0m"
echo -en "\033[37;1;41m IPv6 Subnets - /64, /48, /36, /32 for proxies. \033[0m \n\n"
echo ""

read -p "Press [Enter] to continue..."

echo -e "Configuring IPv6 proxies \n"

echo "Enter the desired subnet and press [ENTER]:"
read network

if [[ $network == *"::/48"* ]]; then
    mask=48
elif [[ $network == *"::/64"* ]]; then
    mask=64
elif [[ $network == *"::/32"* ]]; then
    mask=32
    echo "Enter subnet /64; this is used for connecting /32 subnets. Subnet /64 is assigned in the main network segment - Segment."
    read network_mask
elif [[ $network == *"::/36"* ]]; then
    mask=36
    echo "Enter subnet /64; this is used for connecting /36 subnets. Subnet /64 is assigned in the main network segment - Segment."
    read network_mask
else
    echo "Unknown mask or invalid subnet, please enter a subnet with mask /64, /48, /36, or /32."
    exit 1
fi

echo "Enter the number of address ranges for random generation"
read MAXCOUNT
THREADS_MAX=$(sysctl kernel.threads-max | awk '{print $3}')
MAXCOUNT_MIN=$((MAXCOUNT - 200))
if ((MAXCOUNT_MIN > THREADS_MAX)); then
    echo "kernel.threads-max = $THREADS_MAX is insufficient for the specified number of address ranges!"
fi

echo "Enter the login for the proxy"
read proxy_login
echo "Enter the password for the proxy"
read proxy_pass
echo "Enter the initial port for the proxy"
read proxy_port

prxtp() {
    echo "What type of proxy do you want to use?"
    echo "http (recommended) or socks"
    read proxytype
    if [[ $proxytype != "socks" ]] && [[ $proxytype != "http" ]]; then
        echo "Please enter either 'http' or 'socks'!"
        prxtp
    else
        echo "You will be using $proxytype proxy."
    fi
}

prxtp

if [[ $proxytype == "http" ]]; then
    proxytype=proxy
else
    proxytype=socks
fi

base_net=$(echo $network | awk -F/ '{print $1}')
base_net1=$(echo $network_mask | awk -F/ '{print $1}')

timerrotation() {
    echo "Enter the rotation interval in minutes (1-59)"
    read timer
    if [[ $timer -ge 1 ]] && [[ $timer -le 59 ]]; then
        echo "Rotation will occur every $timer minutes."
    else
        echo "Please specify a number between 1 and 59 for the rotation interval."
        timerrotation
    fi
}
startrotation() {
    echo "Enable rotation? [Y/N]"
    read rotation
    if [[ "$rotation" != [yY] ]] && [[ "$rotation" != [nN] ]]; then
        echo "Invalid input"
        startrotation
    else
        if [[ "$rotation" != [Yy] ]]; then
            echo "You have opted out of using rotation."
        else
            echo "You will be using rotation."
            timerrotation
        fi
    fi
}

startrotation

echo "Configuring proxy settings for subnet $base_net with mask $mask"
sleep 2
echo "Configuring IPv6 address for the network"
ip -6 addr add ${base_net}2 peer ${base_net}1 dev eth0
sleep 5
ip -6 route add default via ${base_net}1 dev eth0
ip -6 route add local ${base_net}/${mask} dev lo

if [ -f /root/3proxy.tar ]; then
    echo "The 3proxy.tar archive is already downloaded; continuing with installation..."
else
    echo "Downloading the 3proxy.tar archive..."
    wget --no-check-certificate https://blog.vpsville.ru/uploads/3proxy.tar
    tar -xvf 3proxy.tar
fi

if [ -f /root/ndppd.tar ]; then
    echo "The ndppd.tar archive is already downloaded; continuing with installation..."
else
    echo "Downloading the ndppd.tar archive..."
    wget --no-check-certificate https://blog.vpsville.ru/uploads/ndppd.tar
    tar -xvf ndppd.tar
fi

if [ -f /root/3proxy/3proxy.cfg ]; then
    echo "3proxy.cfg configuration file found. Deleting it."
    cat /dev/null > /root/3proxy/3proxy.cfg
    cat /dev/null > /root/3proxy/3proxy.sh
    cat /dev/null > /root/3proxy/random.sh
    cat /dev/null > /root/3proxy/rotate.sh
    cat /dev/null > /etc/rc.local
    cat /dev/null > /var/spool/cron/crontabs/root
else
    echo "3proxy.cfg configuration file not found. No changes made."
fi

echo "Configuring ndppd"
mkdir -p /root/ndppd/
rm -f /root/ndppd/ndppd.conf
cat >/root/ndppd/ndppd.conf <<EOL
route-ttl 30000
proxy eth0 {
   router no
   timeout 500
   ttl 30000
   rule __NETWORK__ {
      static
   }
}
EOL
sed -i "s/__NETWORK__/${base_net}\/${mask}/" /root/ndppd/ndppd.conf

echo "Configuring 3proxy"
rm -f /root/ip.list
echo "Generating $MAXCOUNT addresses "
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
count=1
first_blocks=$(echo $base_net | awk -F:: '{print $1}')
rnd_ip_block() {
    a=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
    b=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
    c=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
    d=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
    if [[ "x"$mask == "x48" ]]; then
        e=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
        echo $first_blocks:$a:$b:$c:$d:$e >> /root/ip.list
    elif [[ "x"$mask == "x32" ]]; then
        e=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
        f=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
        echo $first_blocks:$a:$b:$c:$d:$e:$f >> /root/ip.list
    elif [[ "x"$mask == "x36" ]]; then
        num_dots=$(echo $first_blocks | awk -F":" '{print NF-1}')
        if [[ x"$num_dots" == "x1" ]]; then
            # first block
            block_num="0"
            first_blocks_cut=$(echo $first_blocks)
        else
            # 2+ block
            block_num=$(echo $first_blocks | awk -F':' '{print $NF}')
            block_num="${block_num:0:1}"
            first_blocks_cut=$(echo $first_blocks | awk -F':' '{print $1":"$2}')
        fi
        a=${block_num}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
        e=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
        f=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}
        echo $first_blocks_cut:$a:$b:$c:$d:$e:$f >> /root/ip.list
    else
        echo $first_blocks:$a:$b:$c:$d >> /root/ip.list
    fi
}
while [ "$count" -le $MAXCOUNT ]; do
    rnd_ip_block
    let "count += 1"
done
echo "Generating 3proxy configuration"
mkdir -p /root/3proxy
rm /root/3proxy/3proxy.cfg
cat >/root/3proxy/3proxy.cfg <<EOL
daemon
maxconn 10000
nserver 127.0.0.1
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6000
flush
auth strong
users ${proxy_login}:CL:${proxy_pass}
allow ${proxy_login}
EOL

echo >> /root/3proxy/3proxy.cfg
ip4_addr=$(ip -4 addr sh dev eth0 | grep inet | awk '{print $2}')
port=${proxy_port}
count=1
for i in $(cat /root/ip.list); do
    echo "$proxytype -6 -s0 -n -a -p$port -i$ip4_addr -e$i" >> /root/3proxy/3proxy.cfg
    ((port += 1))
    ((count += 1))
done

if grep -q "net.ipv6.ip_nonlocal_bind=1" /etc/sysctl.conf; then
    echo "All parameters in sysctl were already set"
else
    echo "Configuring sysctl"
    echo "net.ipv6.conf.eth0.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.ip_nonlocal_bind=1" >> /etc/sysctl.conf
    echo "vm.max_map_count=195120" >> /etc/sysctl.conf
    echo "kernel.pid_max=195120" >> /etc/sysctl.conf
    echo "net.ipv4.ip_local_port_range=1024 65000" >> /etc/sysctl.conf
    sysctl -p
fi

ip4address=$(hostname -i)
echo "Creating a file with data for connections - $ip4address.list"
proxyport1=$(($proxy_port - 1))
touch -f /root/$ip4address.list
echo "#\!/bin/bash" >> /root/3proxy/$ip4address.sh
chmod +x /root/3proxy/$ip4address.sh
sed -i "s/ip4addr/${ip4address}/" /root/3proxy/$ip4address.sh
echo "/root/3proxy/3proxy /root/3proxy/3proxy.cfg > /dev/null 2>&1 &" >> /root/3proxy/$ip4address.sh
echo "/root/ndppd/ndppd -d -c /root/ndppd/ndppd.conf > /dev/null 2>&1 &" >> /root/3proxy/$ip4address.sh
echo "iptables -t nat -A PREROUTING -p tcp --dport ${proxyport1}:${proxy_port} -j DNAT --to-destination ${ip4address}:${proxyport1}-${proxy_port}" >> /root/3proxy/$ip4address.sh
echo "iptables -t nat -A PREROUTING -p udp --dport ${proxyport1}:${proxy_port} -j DNAT --to-destination ${ip4address}:${proxyport1}-${proxy_port}" >> /root/3proxy/$ip4address.sh
echo "/root/3proxy/3proxy -p${proxyport1}-${proxy_port} -s0 -n -a -e$ip4address" >> /root/3proxy/$ip4address.sh
echo "/root/3proxy/3proxy -s${proxyport1}-${proxy_port} -p0 -n -a -e$ip4address" >> /root/3proxy/$ip4address.sh

echo "Creating a script for changing IP addresses"
touch -f /root/3proxy/$ip4address-changeip.sh
chmod +x /root/3proxy/$ip4address-changeip.sh
echo "#!/bin/bash" >> /root/3proxy/$ip4address-changeip.sh
echo "killall -9 3proxy" >> /root/3proxy/$ip4address-changeip.sh
echo "killall -9 ndppd" >> /root/3proxy/$ip4address-changeip.sh
echo "rm /root/3proxy/3proxy.cfg" >> /root/3proxy/$ip4address-changeip.sh
echo "cat /dev/null > /root/3proxy/3proxy.cfg" >> /root/3proxy/$ip4address-changeip.sh
echo "ip4_addr=\$(ip -4 addr sh dev eth0 | grep inet | awk '{print \$2}')" >> /root/3proxy/$ip4address-changeip.sh
echo "cat >> /root/3proxy/3proxy.cfg <<EOL" >> /root/3proxy/$ip4address-changeip.sh
echo "daemon" >> /root/3proxy/$ip4address-changeip.sh
echo "maxconn 10000" >> /root/3proxy/$ip4address-changeip.sh
echo "nserver 127.0.0.1" >> /root/3proxy/$ip4address-changeip.sh
echo "nscache 65536" >> /root/3proxy/$ip4address-changeip.sh
echo "timeouts 1 5 30 60 180 1800 15 60" >> /root/3proxy/$ip4address-changeip.sh
echo "setgid 65535" >> /root/3proxy/$ip4address-changeip.sh
echo "setuid 65535" >> /root/3proxy/$ip4address-changeip.sh
echo "stacksize 6000" >> /root/3proxy/$ip4address-changeip.sh
echo "flush" >> /root/3proxy/$ip4address-changeip.sh
echo "auth strong" >> /root/3proxy/$ip4address-changeip.sh
echo "users ${proxy_login}:CL:${proxy_pass}" >> /root/3proxy/$ip4address-changeip.sh
echo "allow ${proxy_login}" >> /root/3proxy/$ip4address-changeip.sh

echo >> /root/3proxy/$ip4address-changeip.sh
count=1
for i in $(cat /root/ip.list); do
    echo "$proxytype -6 -s0 -n -a -p$proxy_port -i\$ip4_addr -e$i" >> /root/3proxy/$ip4address-changeip.sh
    ((proxy_port += 1))
    ((count += 1))
done
echo "Creating a script for random IP addresses"
touch -f /root/3proxy/random.sh
chmod +x /root/3proxy/random.sh
echo "#!/bin/bash" >> /root/3proxy/random.sh
echo "i=0" >> /root/3proxy/random.sh
echo "array=()" >> /root/3proxy/random.sh
echo "while IFS= read -r line" >> /root/3proxy/random.sh
echo "do" >> /root/3proxy/random.sh
echo "    array+=($line)" >> /root/3proxy/random.sh
echo "    i=\$((i+1))" >> /root/3proxy/random.sh
echo "done < \"/root/ip.list\"" >> /root/3proxy/random.sh
echo "MAX=\$i" >> /root/3proxy/random.sh
echo "r=\$((0 + RANDOM \% MAX))" >> /root/3proxy/random.sh
echo "echo \"random:\${array[\$r]}\"" >> /root/3proxy/random.sh
echo "i=0" >> /root/3proxy/random.sh
echo "while IFS= read -r line" >> /root/3proxy/random.sh
echo "do" >> /root/3proxy/random.sh
echo "    i=\$((i+1))" >> /root/3proxy/random.sh
echo "    if [ \$i -eq \$r ]; then" >> /root/3proxy/random.sh
echo "        echo \"Rebooting on IP: \$line\"" >> /root/3proxy/random.sh
echo "        echo \"1\" > /root/rebooting.lock" >> /root/3proxy/random.sh
echo "        ndppd_ctl down" >> /root/3proxy/random.sh
echo "        sleep 5" >> /root/3proxy/random.sh
echo "        /sbin/reboot" >> /root/3proxy/random.sh
echo "        sleep 3600" >> /root/3proxy/random.sh
echo "    fi" >> /root/3proxy/random.sh
echo "done < \"/root/ip.list\"" >> /root/3proxy/random.sh
echo "Creating a script for changing IP addresses"
touch -f /root/3proxy/rotate.sh
chmod +x /root/3proxy/rotate.sh
echo "#!/bin/bash" >> /root/3proxy/rotate.sh
echo "echo \"1\" > /root/rebooting.lock" >> /root/3proxy/rotate.sh
echo "ndppd_ctl down" >> /root/3proxy/rotate.sh
echo "sleep 5" >> /root/3proxy/rotate.sh
echo "/sbin/reboot" >> /root/3proxy/rotate.sh
echo "sleep 3600" >> /root/3proxy/rotate.sh

echo "Creating rc.local"
touch -f /etc/rc.local
chmod +x /etc/rc.local
echo "#!/bin/bash" >> /etc/rc.local
echo "/root/3proxy/$ip4address.sh" >> /etc/rc.local
echo "/root/3proxy/random.sh" >> /etc/rc.local
echo "/root/3proxy/rotate.sh" >> /etc/rc.local
echo "exit 0" >> /etc/rc.local

echo "Creating cron job"
touch -f /var/spool/cron/crontabs/root
chmod +x /var/spool/cron/crontabs/root
echo "*/$timer * * * * /root/3proxy/random.sh" >> /var/spool/cron/crontabs/root
echo "*/$timer * * * * /root/3proxy/rotate.sh" >> /var/spool/cron/crontabs/root
echo "ndppd_ctl down" >> /root/3proxy/random.sh

echo "Running ndppd"
/root/ndppd/ndppd -d -c /root/ndppd/ndppd.conf > /dev/null 2>&1 &

echo "Starting 3proxy"
/root/3proxy/3proxy /root/3proxy/3proxy.cfg > /dev/null 2>&1 &

echo "Configuration completed"
echo "Do not forget to add these IP addresses to the server!"
echo "Please reboot the server and make sure that the IPv6 addresses are configured correctly"
echo "The list of IPv6 addresses is located at /root/ip.list"
echo "You can change the IP address of the server randomly or cyclically by running the script: /root/3proxy/random.sh or /root/3proxy/rotate.sh"
echo "To disable this feature, simply run the script /root/3proxy/rotate.sh"
echo "To disable random selection, simply run the script /root/3proxy/random.sh"
echo "When using rotation and rebooting scripts, reboot the server in 1 hour after launching these scripts"
echo "The interval of rebooting and random selection is set by you at the beginning of the script"

echo "Do you want to reboot the server now? [y/n]"
read reboot_choice

if [[ "$reboot_choice" == [yY] ]]; then
    echo "Rebooting the server..."
    sleep 5
    /sbin/reboot
fi

echo "Setup complete. Please reboot the server for the changes to take effect."
