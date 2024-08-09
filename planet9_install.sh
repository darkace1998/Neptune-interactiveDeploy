#!/bin/sh

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

# Get installation directory from user input or command-line argument
if [ "$1" = "-silent" ]; then
    INSTALL_DIR="/opt/neptune-open-edition"
else
    read -p "Enter installation directory (default: /opt/neptune-open-edition): " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-/opt/neptune-open-edition}
fi

# Get service name from user input or command-line argument
if [ "$1" = "-silent" ]; then
    SERVICE_NAME="neptune-open-edition"
else
    read -p "Enter service name (default: neptune-open-edition): " SERVICE_NAME
    SERVICE_NAME=${SERVICE_NAME:-neptune-open-edition}
fi

# Set the default service user
SERVICE_USER="planet9"

# Define the download URL for Neptune DXP – Open Edition
DOWNLOAD_URL="https://stneptuneportal.blob.core.windows.net/downloads/Neptune%20DX%20Platform%20-%20Open%20Edition%2FLong-term%20Maintenance%20Releases%2FDXP%2023%2F23.10.5%20(Patch%205)%2Fplanet9-linux-v23.10.5.zip"

# Create the installation directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Download the Neptune DXP – Open Edition ZIP file
echo "Downloading Neptune DXP – Open Edition..."
curl -o "$INSTALL_DIR/neptune-open-edition.zip" "$DOWNLOAD_URL"

# Unzip the downloaded file
unzip "$INSTALL_DIR/neptune-open-edition.zip" -d "$INSTALL_DIR"

# Make the server file executable
chmod +x "$INSTALL_DIR/planet9-linux"  # Adjust based on the actual server file name

# Start the installation or upgrade
echo "Starting Neptune DXP – Open Edition installation or upgrade..."
"$INSTALL_DIR/planet9-linux" --upgrade  # Use --upgrade for upgrades, remove for fresh installation

echo "Neptune DXP – Open Edition installation or upgrade completed."

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
        echo "Service installation completed. Neptune DXP – Open Edition is now running as a service."
    elif [ -x "$(command -v rc-service)" ]; then
        rc-service "$SERVICE_NAME" start
        rc-update add "$SERVICE_NAME" default
        echo "Service installation completed. Neptune DXP – Open Edition is now running as a service."
    fi
fi
