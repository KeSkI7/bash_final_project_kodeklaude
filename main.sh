#!/bin/bash
function check_if_status_active {
    status=$(systemctl is-active "$1")
    if [ "$status" == "active" ]; then
        echo "$1 is active"
    else
        echo "$1 is not active"
    fi
}

function check_ports_of_firewalld {
    ports=$(sudo firewall-cmd --list-ports)
    if [[ $ports == *"3306/tcp"* ]]; then
        echo "Port 3306 is open in firewalld"
    else
        echo "Port 3306 is not open in firewalld"
    fi
}

function check_if_database_exists {
result=$(sudo mysql -e "show databases;" | grep ecomdb)
    if [ "$result" == "ecomdb" ]; then
        echo "Database ecomdb exists"
    else
        echo "Database ecomdb does not exist"
    fi
}

echo "Installing firewalld..."
sudo yum install firewalld -y
sudo systemctl start firewalld
sudo systemctl enable firewalld
check_if_status_active firewalld

echo "Installing mariadb..."
sudo yum install mariadb-server -y
sudo systemctl start mariadb
sudo systemctl enable mariadb
check_if_status_active mariadb

sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload
check_ports_of_firewalld

sudo mysql << EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
exit
EOF

check_if_database_exists
#Will continue later 