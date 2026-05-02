#!/bin/sh

# Script to automate Whonix Desktop (Xfce) installation on KVM
# Target: Debian-based systems (Debian/Ubuntu)
# Author: Me plus AI based on Whonix official documentation
# Date: May 16, 2025

# Configuration variables
WHONIX_VERSION="17.3.9.9"
DOWNLOAD_URL="https://www.whonix.org/download/libvirt/${WHONIX_VERSION}/Whonix-Xfce-${WHONIX_VERSION}.Intel_AMD64.qcow2.libvirt.xz"
SIGNATURE_URL="${DOWNLOAD_URL}.asc"
WORKING_DIR="$HOME/whonix-install"
LIBVIRT_IMG_DIR="/var/lib/libvirt/images"
GPG_KEY_URL="https://www.whonix.org/keys/derivative.asc"
SIGNATURE_FILE="$HOME/whonix-install/Whonix-Xfce-${WHONIX_VERSION}.Intel_AMD64.qcow2.libvirt.xz.asc"
IMAGE_FILE="$HOME/whonix-install/Whonix-Xfce-${WHONIX_VERSION}.Intel_AMD64.qcow2.libvirt.xz"

# Ensure script is run with sudo privileges
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: This script should not be run as root. Run as a regular user with sudo privileges."
    exit 1
fi

# Function to check for command existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to handle errors
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Function to verify downloaded image #fix 
verify_image() {
    echo "Verifying Whonix image signature..."
    
    # Verify the image signature
    gpg --verify "$SIGNATURE_FILE" "$IMAGE_FILE"
    if [ $? -eq 0 ]; then
        echo "Image verification successful."
    else
        echo "Failed to verify image signature."
        exit 1
    fi
}

# Download signing key
wget --user-agent="Mozilla/5.0(Windows NT 10.0; Win 64; x64) AppleWebkit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" "$GPG_KEY_URL" || error_exit "Failed to download signing key"
    
# Verify then import signing key
gpg --keyid-format long --import --import-options show-only --with-fingerprint derivative.asc
echo "Key Fingerprint 916B 8D99 C38E AF5E 8ADC 7A2A 8D66 066A 2EEA CCDA (yes/no)"
read answer
if  [ "$answer" = "yes" ]; then
	echo "Importing "
echo "916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA:6:" | gpg --import-ownertrust
gpg --import derivative.asc || error_exit "Failed to import signing key"
elif [ "$answer" = "no" ]; then
	echo "Fingerprint Mismatch "
exit
fi

#1

# Step 1: Install dependencies
echo "Installing KVM and related tools..."
sudo apt update || error_exit "Failed to update package lists"
sudo apt install -y \
    qemu-system-x86 \
    libvirt-daemon-system \
    libvirt-clients \
    virt-manager \
    bridge-utils \
    libosinfo-bin \
    virtinst \
    genisoimage \
    xz-utils \
    safe-rm \
    iptables \
    libguestfs-tools \
    dnsmasq-base \
    qemu-utils \
    gpg \
    wget \

# Verify KVM support
if ! command_exists kvm-ok; then
    sudo apt install -y cpu-checker || error_exit "Failed to install cpu-checker"
fi
kvm-ok || error_exit "KVM is not supported on this system"

# Step 2: Add user to libvirt and kvm groups
echo "Adding user to libvirt and kvm groups..."
sudo usermod -a -G libvirt "$(whoami)" || error_exit "Failed to add user to libvirt group"
sudo usermod -a -G kvm "$(whoami)" || error_exit "Failed to add user to kvm group"

# Step 3: Create working directory
echo "Creating working directory at $WORKING_DIR..."
mkdir -p "$WORKING_DIR" || error_exit "Failed to create working directory"
cd "$WORKING_DIR" || error_exit "Failed to change to working directory"

# Step 4: Download Whonix KVM image and signature
echo "Downloading Whonix KVM image (version ${WHONIX_VERSION})..."
wget --user-agent="Mozilla/5.0(Windows NT 10.0; Win 64; x64) AppleWebkit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" "$DOWNLOAD_URL" || error_exit "Failed to download Whonix image"
wget --user-agent="Mozilla/5.0(Windows NT 10.0; Win 64; x64) AppleWebkit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" "$SIGNATURE_URL" || error_exit "Failed to download signature"

# Step 5: Verify downloaded image
verify_image

# Step 6: Extract the image
echo "Extracting Whonix image..."
tar -xvf "Whonix-Xfce-${WHONIX_VERSION}.Intel_AMD64.qcow2.libvirt.xz" || error_exit "Failed to extract image"

# Step 7: Move image files to libvirt directory
echo "Moving image files to $LIBVIRT_IMG_DIR..."
sudo mv "Whonix-Gateway-Xfce-${WHONIX_VERSION}.Intel_AMD64.qcow2" "${LIBVIRT_IMG_DIR}/Whonix-Gateway.qcow2" || error_exit "Failed to move Gateway image"
sudo mv "Whonix-Workstation-Xfce-${WHONIX_VERSION}.Intel_AMD64.qcow2" "${LIBVIRT_IMG_DIR}/Whonix-Workstation.qcow2" || error_exit "Failed to move Workstation image"

# Step 8: Define virtual networks
echo "Defining Whonix virtual networks..."
sudo virsh -c qemu:///system net-define "Whonix_external_network.xml" || error_exit "Failed to define external network1"
sudo virsh -c qemu:///system net-define "Whonix_internal_network.xml" || error_exit "Failed to define internal network2"
sudo virsh -c qemu:///system net-autostart Whonix-External || error_exit "Failed to set autostart for external network3"
sudo virsh -c qemu:///system net-start Whonix-External || error_exit "Failed to start external network4"
sudo virsh -c qemu:///system net-autostart Whonix-Internal || error_exit "Failed to set autostart for internal network5"
sudo virsh -c qemu:///system net-start Whonix-Internal || error_exit "Failed to start internal network6"

# Step 9: Define virtual machines
echo "Defining Whonix Gateway and Workstation VMs..."
sudo virsh -c qemu:///system define "Whonix-Gateway.xml" || error_exit "Failed to define Gateway VM7"
sudo virsh -c qemu:///system define "Whonix-Workstation.xml" || error_exit "Failed to define Workstation VM8"

# Step 10: Prompt user to reboot
echo "Installation complete. A reboot is recommended to apply group changes."
read -p "Would you like to reboot now? (y/N): " reboot_choice
if [ "$reboot_choice" = "y" ] || [ "$reboot_choice" = "Y" ]; then
    echo "Rebooting system..."
    sudo reboot
else
    echo "Please reboot manually later to apply group changes."
fi

# Step 11: Final instructions
echo "Whonix installation completed successfully!"
echo "Next steps:"
echo "1. Open 'Virtual Machine Manager' (virt-manager) or use 'virsh' to manage VMs."
echo "2. Start the Whonix-Gateway VM first, then the Whonix-Workstation VM."
echo "3. Ensure both VMs are updated after booting (sudo apt update && sudo apt upgrade)."
echo "4. Refer to https://www.whonix.org/wiki/KVM for further configuration."