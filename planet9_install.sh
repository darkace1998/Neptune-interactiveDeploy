#!/bin/bash

# Check if unzip and curl are installed, and install them if needed
if ! command -v unzip >/dev/null 2>&1; then
    echo "Installing unzip..."
    if [ -x "$(command -v apt)" ]; then
        apt-get update
        apt-get install -y unzip
    elif [ -x "$(command -v yum)" ]; then
        yum install -y unzip
    elif [ -x "$(command -v zypper)" ]; then
        zypper install -y unzip
    elif [ -x "$(command -v pacman)" ]; then
        pacman -Syu --noconfirm unzip
    else
        echo "Unzip installation failed. Please install unzip manually."
        exit 1
    fi
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    if [ -x "$(command -v apt)" ]; then
        apt-get update
        apt-get install -y curl
    elif [ -x "$(command -v yum)" ]; then
        yum install -y curl
    elif [ -x "$(command -v zypper)" ]; then
        zypper install -y curl
    elif [ -x "$(command -v pacman)" ]; then
        pacman -Syu --noconfirm curl
    else
        echo "Curl installation failed. Please install curl manually."
        exit 1
    fi
fi

# Get installation directory from user input
read -p "Enter installation directory (default: /var/planet9): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/var/planet9}

# Get service name from user input
read -p "Enter service name (default: planet9): " SERVICE_NAME
SERVICE_NAME=${SERVICE_NAME:-planet9}

# Set the default service user
SERVICE_USER="planet9"

# Define the download URL for Neptune DXP – Open Edition
DOWNLOAD_URL="https://stneptuneportal.blob.core.windows.net/downloads/Neptune%20DX%20Platform%20-%20Open%20Edition/Long-term%20Maintenance%20Releases/DXP%2022/22.10.7%20(Patch%207)/planet9-linux-v22.10.7.zip"

# Ask the user whether to install or upgrade
echo "Choose an action:"
echo "1. Install (Default)"
echo "2. Upgrade"
read -p "Enter your choice (1/2): " CHOICE

# Set default to 1 (Install) if input is empty
CHOICE=${CHOICE:-1}

# Perform the selected action
case $CHOICE in
    1)
        # Create the installation directory if it doesn't exist
        mkdir -p "$INSTALL_DIR"

        # Download the Neptune DXP – Open Edition ZIP file
        echo "Downloading Neptune DXP – Open Edition..."
        curl -o "$INSTALL_DIR/neptune-open-edition.zip" "$DOWNLOAD_URL"

        # Unzip the downloaded file
        unzip "$INSTALL_DIR/neptune-open-edition.zip" -d "$INSTALL_DIR"

        # Make the server file executable
        chmod +x "$INSTALL_DIR/planet9-linux"  # Adjust based on the actual server file name
        ;;
    2)
        # Start the upgrade
        echo "Starting Neptune DXP – Open Edition upgrade..."
		cd "$INSTALL_DIR"
        "$INSTALL_DIR/planet9-linux" --upgrade
        echo "Neptune DXP – Open Edition upgrade completed."
        ;;
    *)
        echo "Invalid choice. No action performed."
        ;;
esac

# Create the service user (requires superuser privileges)
if ! id "$SERVICE_USER" &>/dev/null; then
    echo "Creating service user: $SERVICE_USER"
    useradd -r -s /usr/sbin/nologin "$SERVICE_USER"
fi

# Set ownership and permissions
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"

# Install the service (detect and use appropriate init system)
SERVICE_FILE=""

# Detect the init system
if [ -x "$(command -v systemctl)" ]; then
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    echo "Detected systemd init system..."
elif [ -x "$(command -v rc-service)" ]; then
    SERVICE_FILE="/etc/init.d/$SERVICE_NAME"
    echo "Detected OpenRC init system..."
else
    echo "Unsupported or unrecognized init system. Manual service installation required."
fi

if [ -n "$SERVICE_FILE" ]; then
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Neptune DXP – Open Edition Service
[Service]
ExecStart=$INSTALL_DIR/planet9-linux
Restart=always
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
[Install]
WantedBy=multi-user.target
EOF

    # Reload init system and start the service
    if [ -x "$(command -v systemctl)" ]; then
        systemctl daemon-reload
        systemctl enable "$SERVICE_NAME"
        systemctl start "$SERVICE_NAME"
        echo "Service installation completed. Neptune DXP – Open Edition is now running as a service give the service 2 minutes to start."
    elif [ -x "$(command -v rc-service)" ]; then
        rc-service "$SERVICE_NAME" start
        rc-update add "$SERVICE_NAME" default
        echo "Service installation completed. Neptune DXP – Open Edition is now running as a service give the service 2 minutes to start."
    fi
fi