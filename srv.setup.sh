#!/bin/bash
# setup script for shme

# check run as 'root'
if [[ "$(id -u)" > "0" ]]; then
    echo "[!] Please run script as root."
    exit
fi

# check if apache is installed
apache2 -v > /dev/null 2>&1
if (($? > 0)); then
    echo "[!] Missing dependency \"apache2\""
    echo "[~] Installing apache2..."
    apt install apache2 -y > /dev/null
    if (($? > 0)); then
        echo "[!] An error occurred while installing Apache2"
        exit
    else
        echo "[✔] Apache2 successfully instlled."
    fi
fi

# replace 000-default
cp res/000-default.conf /etc/apache2/sites-available/
systemctl restart apache2