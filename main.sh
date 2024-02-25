#!/bin/bash

# Function to check if a package is installed
is_package_installed() {
    dpkg -l "$1" &> /dev/null
    return $?
}

echo "Checking and installing required packages..."
echo "--------------------------------------------"
# Install required packages if they are not already installed
REQUIRED_PACKAGES=("dmidecode" "lshw" "net-tools" "smartmontools" "util-linux" "hdparm" "nvme-cli")
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! is_package_installed "$pkg"; then
        echo "$pkg is not installed. Installing..."
        sudo apt-get update && sudo apt-get install -y "$pkg"
        echo "" # Line break for readability
    else
        echo "$pkg is already installed."
        echo "" # Line break for readability
    fi
done

echo "Collecting system information..."
echo "--------------------------------"

# System Information
PC_NAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')
MANUFACTURER_INFO=$(sudo dmidecode -s system-manufacturer)
MODEL_INFO=$(sudo dmidecode -s system-product-name)
CPU_INFO=$(lscpu | grep "Model name:" | sed 's/Model name: *//')
CPU_CORES=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
RAM_INFO=$(sudo lshw -class memory | grep -A 5 "System Memory" | grep size | awk '{print $2 $3}')
RAM_TYPE=$(sudo dmidecode --type memory | grep Type: | head -1 | awk '{print $2}')

# Display Basic System Information
echo -e "\nBasic System Information:"
echo "--------------------------------"
echo "PC Name: $PC_NAME"
echo "IP Address: $IP_ADDRESS"
echo "Manufacturer: $MANUFACTURER_INFO $MODEL_INFO"
echo "CPU: $CPU_INFO, Cores: $CPU_CORES"
echo "RAM: $RAM_INFO, Type: $RAM_TYPE"
echo "--------------------------------"

# Ensure the script is run with root privileges to access hdparm details
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit
fi

echo "Analyzing storage devices..."
echo "--------------------------------"

# Get list of block devices
devices=$(lsblk -dno NAME,TYPE | grep disk | awk '{print $1}')

for device in $devices; do
    echo -e "\nProcessing /dev/$device ..."
    echo "--------------------------------"

    # Getting basic device info
    device_info=$(lsblk -dno NAME,SIZE,VENDOR,MODEL /dev/$device)
    echo "Basic Info: $device_info"

    # Determine if device is SSD, HDD, NVMe, etc.
    device_type=$(cat /sys/block/$device/queue/rotational)
    case $device_type in
        0) echo "Type: SSD/NVMe"
           if [ -d "/sys/class/nvme/${device}" ]; then
               echo "Confirmed: NVMe"
           else
               echo "Assumed: SSD"
           fi
           ;;
        1) echo "Type: HDD"
           ;;
        *) echo "Unknown type"
           ;;
    esac

    # Smartctl to get detailed info including model name
    if smartctl -i /dev/$device &> /dev/null; then
        echo "SMART Info:"
        smartctl -i /dev/$device | grep -E "Model Family|Device Model|Serial Number|Firmware Version|User Capacity"
        model_info=$(smartctl -i /dev/$device | grep "Device Model")
        if [[ ! -z "$model_info" ]]; then
            echo "Common Name: ${model_info#*: }"
        else
            echo "Common Name: Not found"
        fi

        # Attempt to get the speed of the device
        if [ "$device_type" -eq "0" ]; then
            echo "Speed: SSD/NVMe speeds require benchmark tools to measure accurately."
        elif [ "$device_type" -eq "1" ]; then
            if command -v hdparm &> /dev/null; then
                speed_info=$(hdparm -tT /dev/$device | grep -E "Timing buffered disk reads")
                echo "$speed_info"
            else
                echo "hdparm not installed, cannot measure HDD speed."
            fi
        fi
    else
        echo "SMART not supported or enabled for /dev/$device."
    fi

    echo "----------------------------------------"
done
