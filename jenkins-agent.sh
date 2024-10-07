#!/bin/bash

# Usage information
usage() {
    echo "Usage: $0 -m JENKINS_MASTER_URL -n AGENT_NAME -s AGENT_SECRET [-d AGENT_WORKDIR] [-u JENKINS_USER]"
    echo "  -m JENKINS_MASTER_URL: URL of the Jenkins master (e.g., http://192.168.1.100:8080)"
    echo "  -n AGENT_NAME: Name of the Jenkins agent (node)"
    echo "  -s AGENT_SECRET: Secret key for the Jenkins agent"
    echo "  -d AGENT_WORKDIR: (Optional) Directory where the agent will store its data (default: /home/jenkins)"
    echo "  -u JENKINS_USER: (Optional) Username to run the agent (default: jenkins)"
    exit 1
}

# Default values
AGENT_WORKDIR="/home/jenkins"
JENKINS_USER="jenkins"

# Parse command-line arguments
while getopts ":m:n:s:d:u:" opt; do
    case ${opt} in
    m)
        JENKINS_MASTER_URL=$OPTARG
        ;;
    n)
        AGENT_NAME=$OPTARG
        ;;
    s)
        AGENT_SECRET=$OPTARG
        ;;
    d)
        AGENT_WORKDIR=$OPTARG
        ;;
    u)
        JENKINS_USER=$OPTARG
        ;;
    \?)
        echo "Invalid option: $OPTARG" 1>&2
        usage
        ;;
    :)
        echo "Invalid option: $OPTARG requires an argument" 1>&2
        usage
        ;;
    esac
done

# Check if required arguments are provided
if [ -z "$JENKINS_MASTER_URL" ] || [ -z "$AGENT_NAME" ] || [ -z "$AGENT_SECRET" ]; then
    echo "Error: Missing required arguments"
    usage
fi

AGENT_JAR="$AGENT_WORKDIR/agent.jar"
AGENT_SERVICE_FILE="/etc/systemd/system/jenkins-agent.service"

# Install Java if not installed
if ! java -version >/dev/null 2>&1; then
    echo "Java not found, installing Java..."
    sudo apt update
    sudo apt install -y openjdk-11-jre
fi

# Add Docker's official GPG key:
if ! docker --version >/dev/null; then
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Create Jenkins user if not exists
#   sudo useradd -m -s /bin/bash $JENKINS_USER
sudo adduser --group --system --home $AGENT_WORKDIR --shell /bin/bash $JENKINS_USER
echo "User $JENKINS_USER created."
# Add Jenkins user to the Docker group
sudo usermod -aG docker $JENKINS_USER
sudo usermod -aG sudo $JENKINS_USER
echo "Jenkins user added to Docker group."

# Download the Jenkins agent JAR
echo "Downloading agent.jar from Jenkins master..."
sudo wget -O "$AGENT_JAR" "$JENKINS_MASTER_URL/jnlpJars/agent.jar"
sudo chown $JENKINS_USER:$JENKINS_USER "$AGENT_JAR"

echo "Creating start script"
cat <<EOF | sudo tee $AGENT_WORKDIR/start-agent.sh
#!/bin/bash
cd $AGENT_WORKDIR
sudo wget -O "$AGENT_JAR" "$JENKINS_MASTER_URL/jnlpJars/agent.jar"
java -jar $AGENT_JAR -url $JENKINS_MASTER_URL -secret $AGENT_SECRET -workDir "$AGENT_WORKDIR" -name "$AGENT_NAME"
exit 0
EOF

# Create systemd service for Jenkins agent
echo "Creating systemd service for Jenkins agent..."
cat <<EOF | sudo tee $AGENT_SERVICE_FILE
[Unit]
Description=Jenkins Agent
After=network.target

[Service]
User=$JENKINS_USER
WorkingDirectory=$AGENT_WORKDIR
ExecStart=/bin/bash $AGENT_WORKDIR/start-agent.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to register the new service
echo "Reloading systemd and starting Jenkins agent service..."
sudo systemctl daemon-reload
sudo systemctl enable jenkins-agent
sudo systemctl start jenkins-agent

# Check the service status
echo "Checking Jenkins agent service status..."
sudo systemctl status jenkins-agent --no-pager
