wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-386.tar.gz -O node_exporter.tar.gz

tar -xvf node_exporter.tar.gz

cd node_exporter-1.8.2.linux-386/

# Move the binary to /usr/local/bin for global access
sudo mv node_exporter /usr/local/bin/

echo "Creating node_exporter systemd service..."

sudo cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create a new user with no home directory and shell
sudo useradd --no-create-home --shell /bin/false node_exporter

sudo systemctl daemon-reload
sudo systemctl start node_exporter

sudo systemctl enable node_exporter

sudo systemctl status node_exporter

cd ..
rm -r node_exporter-1.8.2.linux-386
rm node_exporter.tar.gz