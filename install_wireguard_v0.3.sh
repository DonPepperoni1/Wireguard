#!/bin/bash

# Nom		    : install désinstall wireguard
# Description	: permet d'installer et désinstaller wireguard en fonction des paramètres
# Param 1	    : -i    installer wireguard
# Param 2	    : -d    désinstaller wireguard / clean la conf
# Auteur	    : Matteo MARTINI Thomas LE VOT Margaux TELA
# Email		    : matteo.martini@protonmail.com

function printHelp() {
    echo "USAGE :             ./install_wireguard_v0.3.sh [-h] [-i] [-c]"
    echo "USAGE :              Connaitre l'ip publique de wireguard + clé privée pour se connecter depuis le client"
    echo "USAGE :              IP publique  : cat /etc/wireguard/public_ip.txt"
    echo "USAGE :              Clé publique : cat /etc/wireguard/wg-private.key"
    echo "Param :  -h          Print ce message d'aide"
    echo "Param :  -i          installer et configurer wireguard"
    echo "Param :  -d          clean la conf existante de wireguard"
}

function install_wireguard(){
    apt install sudo tree mc vim rsync net-tools mlocate htop screen -y

    wget https://github.com/cheat/cheat/releases/download/4.2.3/cheat-linux-amd64.gz
    gunzip cheat-linux-amd64.gz
    chmod a+x cheat-linux-amd64
    mv -v cheat-linux-amd64 /usr/local/bin/cheat

    apt install git -y
    mkdir -pv /opt/COMMUN/cheat/cheatsheets/community
    mkdir -v /opt/COMMUN/cheat/cheatsheets/personal
    cheat --init > /opt/COMMUN/cheat/conf.yml
    sed -i 's;/root/.config/; /opt/COMMUN/;' /opt/COMMUN/cheat/conf.yml
    git clone https://github.com/cheat/cheatsheets.git
    mv -v cheatsheets/[a-z]* /opt/COMMUN/cheat/cheatsheets/community

    groupadd -g 10000 commun 
    chgrp -Rv commun /opt/COMMUN/
    chmod 2770 /opt/COMMUN/cheat/cheatsheets/personal
    #find /opt/COMMUN/cheat/cheatsheets/personal -type d -exec chmod 2770 {} \;
    #find /opt/COMMUN/ -type f -exec chmod 660 {} \;

    useradd -m -G 10000 -s /bin/bash esgi
    echo -e 'esgi\nesgi' | sudo passwd esgi
    usermod -aG sudo esgi
    usermod -aG commun esgi
    echo "umask 007 " >> /home/esgi/.bashrc
    mkdir -v /home/esgi/.config 
    ln -s /opt/COMMUN/cheat /home/esgi/.config/cheat 
    chown -R esgi /home/esgi/.config
    useradd -m -G 10000 -s /bin/bash davy
    echo -e 'davy\ndavy' | sudo passwd davy
    usermod -aG sudo davy
    usermod -aG commun davy
    echo "umask 007 " >> /home/davy/.bashrc
    mkdir -v /home/davy/.config
    ln -s /opt/COMMUN/cheat /home/davy/.config/cheat 
    chown -R davy /home/davy/.config

    mkdir -v /root/.config
    ln -s /opt/COMMUN/cheat /root/.config/cheat
    mkdir /etc/skel/.config/
    ln -s /opt/COMMUN/cheat /etc/skel/.config/cheat
    echo "umask 007" >> /etc/skel/.bashrc
    cat >> /root/.bashrc << EOF
    alias ll="ls -rtl"
    alias grep="grep --color"
    alias rm="rm -vi --preserve-root"
    alias chown="chown -v --preserve-root"
    alias chmod="chmod -v --preserve-root"
    alias chgrp="chgrp -v --preserve-root"
EOF
    # Installation Wireguard, configuration interface
    apt update
    apt install wireguard -y | tee -a /root/install_wireguard.log
    # apt install ufw | tee -a /root/install_wireguard.log

    mkdir -p /etc/wireguard/keys
    umask 077
    # Création de la clé privée
    wg genkey > /etc/wireguard/keys/server-private.key
    # Création de la clé publique à partie de la clé privée
    wg pubkey < /etc/wireguard/keys/server-private.key > /etc/wireguard/keys/server-public.key

    # il faut connaitre votre la clé privée et l'ip publique de wireguard pour se connecter
    ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')


    servpriv_key=$(cat /etc/wireguard/keys/server-private.key)
    servpub_key=$(cat /etc/wireguard/keys/server-public.key)

    cat << EOF > /etc/hosts
127.0.0.1   localhost
127.0.1.1   Wireguard
$ip         wireguard.local
EOF

    echo "Wireguard" > /etc/hostname

    dig +short txt ch whoami.cloudflare @1.0.0.1 | tr -d '"' > /etc/wireguard/public_ip.txt
    public_ip=$(cat /etc/wireguard/public_ip.txt)
    interface=$(cat /etc/wireguard/base_interface.txt)

    cat << EOF > /etc/wireguard/wg0.conf
[Interface]
Address = $ip/24
SaveConfig = True
ListenPort = 8888
PrivateKey = $(cat /etc/wireguard/keys/server-private.key)

[Peer]
PublicKey = bexfFoZopmYzbwkVvqZjC+MlGDL6zwMRaOQ5g5Jv12A=
Endpoint = $public_ip:8888
AllowedIPs = 192.168.1.100/24, 192.168.1.52
PersistentKeepalive = 25
EOF

    sysctl -w net.ipv4.ip_forward=1
    chmod 600 /etc/wireguard/wg0.conf
    wg-quick up wg0
    systemctl enable wg-quick@wg0.service
    iptables -A FORWARD -i wg0 -j ACCEPT
    iptables -A FORWARD -o wg0 -j ACCEPT
    iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
    wg show wg0
    echo "Terminé !"
}


function delete_wireguard() {
    rm -rf /etc/wireguard/
    wg-quick down wg0
    systctl -w net.ipv4.ip_forward=0
    apt-get purge --autoremove wireguard -y
}


if [ $# = 0 ] || [ $1 = "-h" ]; then
    printHelp

elif [ $1 = "-i" ]; then
    install_wireguard

elif [ $1 = "-d" ]; then
    delete_wireguard
fi