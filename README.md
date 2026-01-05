# gitlab-selfhosted-runner

GitLab Self-Hosted Linux Runner. General purpose Docker image with pre-installed tools.

[![CodeQL](https://github.com/fok666/gitlab-selfhosted-runner/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/fok666/gitlab-selfhosted-runner/actions/workflows/github-code-scanning/codeql) [![Dependabot Updates](https://github.com/fok666/gitlab-selfhosted-runner/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/fok666/gitlab-selfhosted-runner/actions/workflows/dependabot/dependabot-updates) [![Docker Image CI](https://github.com/fok666/gitlab-selfhosted-runner/actions/workflows/docker-image.yml/badge.svg)](https://github.com/fok666/gitlab-selfhosted-runner/actions/workflows/docker-image.yml)

Goals:

- Run anywhere
- Auto scalable
- Self-configurable
- Feature rich
- Customizable


## Features

Bundled tools:

- [Docker-in-Docker](https://docs.docker.com/engine/install/)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli-linux)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Powershell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)
- [Azure Powershell modules](https://learn.microsoft.com/powershell/azure/install-azps-linux)
- [AWS Tools for PowerShell (bundle)](https://aws.amazon.com/powershell/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [Kubelogin](https://github.com/Azure/kubelogin/releases)
- [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [Helm](https://helm.sh/docs/intro/install/)
- [JQ](https://github.com/jqlang/jq) & [YQ](https://github.com/mikefarah/yq)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [OpenTofu](https://opentofu.org/docs/intro/install/)
- [Terraspace](https://terraspace.cloud/docs/install/)


## Build configuration

Supported `--build-arg` variables are listed below to easily configure the runner image based on your requirements. All options default to 1 (enabled).

- `ADD_DOCKER`: Installs Docker for Docker-in-Docker support
- `ADD_AZURE_CLI`: Installs Azure-CLI
- `ADD_AWS_CLI`:  Installs AWS-CLI
- `ADD_POWERSHELL`: Installs Powershell
- `ADD_AZURE_PWSH_CLI`: Installs Azure Powershell modules, if Powershell is also enabled
- `ADD_AWS_PWSH_CLI`: Installs AWS Powershell modules, if Powershell is also enabled
- `ADD_KUBECTL`: Installs Kubernetes `kubectl`
- `ADD_KUBELOGIN`: Installs Kubernetes `kubelogin` for Azure authentication
- `ADD_KUSTOMIZE`: Installs Kubernetes `kustomize` tool
- `ADD_HELM`: Installs `Helm` tool
- `ADD_JQ`: Installs `jq` tool
- `ADD_YQ`: Installs `yq` tool
- `ADD_TERRAFORM`: Installs `terraform` tool
- `ADD_OPENTOFU`: Installs `opentofu` tool
- `ADD_TERRASPACE`: Installs `terraspace` tool
- `ADD_SUDO`: Installs and enables `sudo` for the runner user group

# References


### GitLab Runner
https://docs.gitlab.com/runner/


### Docker Hub images
https://hub.docker.com/r/fok666/gitlab-runner


### GitLab CI/CD Self-Hosted Runners Reference
https://docs.gitlab.com/runner/install/docker.html


## Running

This runner is intended to run on virtual machines.  
To be able to build Docker images with the runner, docker must be installed on the host and allowed to run in [privileged](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) mode.  


``` bash
# Docker install:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker startup:
sudo systemctl start docker
sudo systemctl enable docker

# Get the runner management scripts and make them executable:
sudo curl -sO https://raw.githubusercontent.com/fok666/gitlab-selfhosted-runner/main/run.sh
sudo curl -sO https://raw.githubusercontent.com/fok666/gitlab-selfhosted-runner/main/stop.sh
sudo curl -sO https://raw.githubusercontent.com/fok666/gitlab-selfhosted-runner/main/vmss_monitor.sh
sudo curl -sO https://raw.githubusercontent.com/fok666/gitlab-selfhosted-runner/main/ec2_monitor.sh
sudo chmod +x *.sh

# Set the parameters from GitLab:
export GITLAB_URL="https://gitlab.com"
export GITLAB_TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxxxx"
export RUNNER_TAGS="docker,linux"

# Start the runners in privileged mode, one runner for each vCPU (default), using the parameters above:
sudo ./run.sh fok666/gitlab-runner:latest $GITLAB_URL $GITLAB_TOKEN $RUNNER_TAGS

# Or specify a custom number of runners (e.g., 4 runners):
sudo ./run.sh fok666/gitlab-runner:latest $GITLAB_URL $GITLAB_TOKEN $RUNNER_TAGS 4
```


## Cloud Provider Support

This project supports graceful shutdown for multiple cloud providers:

### Azure VMSS (Virtual Machine Scale Sets)
- `vmss_monitor.sh`: Monitor Azure VMSS scheduled events for termination notices
- Reference: https://learn.microsoft.com/en-us/azure/virtual-machines/linux/scheduled-events

### AWS EC2 Spot Instances
- `ec2_monitor.sh`: Monitor EC2 spot instance termination notices
- Reference: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-instance-termination-notices.html

### Setup

```bash
# Copy stop script to /opt for monitor scripts to use:
sudo cp stop.sh /opt/stop.sh
sudo chmod +x /opt/stop.sh

# For Azure VMSS - check every minute:
(crontab -l 2>/dev/null; echo "* * * * * /opt/vmss_monitor.sh >> /var/log/vmss_monitor.log 2>&1") | crontab -

# For AWS EC2 Spot - check every 5 seconds:
(crontab -l 2>/dev/null; echo "* * * * * /opt/ec2_monitor.sh >> /var/log/ec2_monitor.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * sleep 5; /opt/ec2_monitor.sh >> /var/log/ec2_monitor.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * sleep 10; /opt/ec2_monitor.sh >> /var/log/ec2_monitor.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * sleep 15; /opt/ec2_monitor.sh >> /var/log/ec2_monitor.log 2>&1") | crontab -
```

Both monitor scripts require `curl` and `jq` to be installed.


# TO DO

- Add Google Compute Cloud (GCP) CLI bundles
- Add GKE auth support
- Add GCP Preemptible VM support
