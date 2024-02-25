#!/bin/bash

#!/bin/bash

# Update and install necessary packages
sudo apt-get update
sudo apt-get install -y dmidecode lshw net-tools

# Gather system information
PC_NAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')
MANUFACTURER_INFO=$(sudo dmidecode -s system-manufacturer)
MODEL_INFO=$(sudo dmidecode -s system-product-name)
CPU_INFO=$(lscpu | grep "Model name:" | sed 's/Model name: *//')
CPU_CORES=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
CPU_SPEED=$(lscpu | grep "MHz" | awk '{print $3 " MHz"}')
RAM_INFO=$(sudo lshw -class memory | grep -A 5 "System Memory" | grep size | awk '{print $2 $3}')
RAM_TYPE=$(sudo dmidecode --type memory | grep Type: | head -1 | awk '{print $2}')

# Display the information
echo "PC Name: $PC_NAME"
echo "IP Address: $IP_ADDRESS"
echo "Manufacturer: $MANUFACTURER_INFO $MODEL_INFO"
echo "CPU: $CPU_INFO, Cores: $CPU_CORES, Speed: $CPU_SPEED"
echo "RAM: $RAM_INFO, Type: $RAM_TYPE"
