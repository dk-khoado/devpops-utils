#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo."
  exit 1
fi

# Get the latest version of Prometheus
PROMETHEUS_VERSION="2.54.1"

# Determine system architecture
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
elif [[ "$ARCH" == "armv7l" ]]; then
  ARCH="armv7"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Set download URL based on architecture
DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-$ARCH.tar.gz"

# Download Prometheus
echo "Downloading Prometheus $PROMETHEUS_VERSION for $ARCH..."
wget $DOWNLOAD_URL -O prometheus.tar.gz

if [ $? -ne 0 ]; then
  echo "Failed to download Prometheus."
  exit 1
fi

# Extract the downloaded archive
echo "Extracting Prometheus..."
tar -xvzf prometheus.tar.gz
cd prometheus-$PROMETHEUS_VERSION.linux-$ARCH || exit 1

# Move binaries to /usr/local/bin
echo "Moving Prometheus binaries to /usr/local/bin..."
mv prometheus promtool /usr/local/bin/

# Create Prometheus user and group
echo "Creating prometheus user and group..."
useradd --no-create-home --shell /bin/false prometheus

# Create necessary directories and set permissions
echo "Setting up directories and permissions..."
mkdir -p /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Move config files to /etc/prometheus
mv prometheus.yml /etc/prometheus/
mv consoles/ console_libraries/ /etc/prometheus/

# Set ownership for config files
chown -R prometheus:prometheus /etc/prometheus

# Create systemd service file
echo "Creating Prometheus systemd service..."
cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Monitoring System
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/etc/prometheus/prometheus.yml \\
    --storage.tsdb.path=/var/lib/prometheus/ \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries \\
    --web.listen-address=:9090 \\
    --web.external-url=

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start Prometheus service
echo "Reloading systemd daemon and starting Prometheus..."
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

# Cleanup downloaded files
cd ..
rm -rf prometheus-$PROMETHEUS_VERSION.linux-$ARCH prometheus.tar.gz

# Check Prometheus status
systemctl status prometheus --no-pager

echo "Prometheus installation completed. Access it via http://localhost:9090"
