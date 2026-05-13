#!/bin/bash
function check_if_status_active {
    status=$(systemctl is-active "$1")
    if [ "$status" == "active" ]; then
        echo "$1 is active"
    else
        echo "$1 is not active"
    fi
}
sudo yum install firewalld -y
sudo systemctl start firewalld
sudo systemctl enable firewalld
check_if_status_active firewalld
#will finish later
