FROM ubuntu:24.04

ARG TARGETARCH
ARG AGENT_VERSION=18.7.1
# ARG for optional components, defaults to 1 (enabled), set to 0 to disable
ARG ADD_DOCKER=1
# Cloud CLIs
ARG ADD_AZURE_CLI=1
ARG ADD_AWS_CLI=1
# PowerShell and Modules
ARG ADD_POWERSHELL=1
ARG ADD_AZURE_PWSH_CLI=1
ARG ADD_AWS_PWSH_CLI=1
# K8s components
ARG ADD_KUBECTL=1
ARG ADD_KUBELOGIN=1
ARG ADD_KUSTOMIZE=1
ARG ADD_HELM=1
# IaC
ARG ADD_TERRAFORM=1
ARG ADD_OPENTOFU=1
ARG ADD_TERRASPACE=1
# Common Tools
ARG ADD_YQ=1
ARG ADD_JQ=1
# Security
ARG ADD_SUDO=1

LABEL org.opencontainers.image.source=https://github.com/fok666/gitlab-selfhosted-runner
LABEL org.opencontainers.image.description="GitLab Self-Hosted Runner"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.authors="Fernando Korndorfer"
LABEL org.opencontainers.image.version="${AGENT_VERSION}"
LABEL org.opencontainers.image.base.name="ubuntu"
LABEL org.opencontainers.image.base.version="24.04"

USER root

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive

# Install agent dependencies...
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes \
    && apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    software-properties-common \
    ca-certificates \
    curl \
    wget \
    bzip2 \
    zip \
    unzip \
    xz-utils \
    git \
    netcat-traditional \
    iputils-ping \
    gss-ntlmssp \
    ucf \
    debsums \
    libcurl4 \
    libicu-dev \
    libunwind8 \
    libxcb1 \
    libnss3 \
    libssl-dev\
    libssl3 \
    liblttng-ust-common1t64 \
    liblttng-ust-ctl5t64 \
    liblttng-ust1t64 \
    libnuma1 \
    libdpkg-perl \
    libfile-fcntllock-perl \
    libfile-fnmatch-perl \
    liblocale-gettext-perl \
    && apt-get upgrade \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install sudo...
# SECURITY NOTE: NOPASSWD:ALL is configured for CI/CD automation purposes.
# This allows the agent user to execute commands with sudo without password prompts.
# This is a security trade-off for CI/CD runner functionality.
RUN test "${ADD_SUDO}" = "1" || exit 0 && \
    apt-get update && apt-get install -y --no-install-recommends sudo \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "%agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent

# Install Docker
RUN test "${ADD_DOCKER}" = "1" || exit 0 && \
    apt-get update && apt-get install -y --no-install-recommends docker.io \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install awscli
# Install awscli (official installer for Ubuntu 24.04+)
RUN test "${ADD_AWS_CLI}" = "1" || exit 0 && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Install jq
RUN test "${ADD_JQ}" = "1" || exit 0 && \
    apt-get update && apt-get install -y --no-install-recommends jq \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install latest Azure CLI https://learn.microsoft.com/cli/azure/install-azure-cli-linux
RUN test "${ADD_AZURE_CLI}" = "1" || exit 0 && \
    curl -sLS "https://aka.ms/InstallAzureCLIDeb" -o /tmp/install-azure-cli.sh \
    && bash /tmp/install-azure-cli.sh \
    && rm /tmp/install-azure-cli.sh \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* \
    && az config set extension.use_dynamic_install=yes_without_prompt \
    && az extension add --name azure-devops \
    && az extension add --name resource-graph

# Install latest PowerShell https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
RUN test "${ADD_POWERSHELL}" = "1" || exit 0 && \
    PWSH_VERSION=$(curl -sI https://github.com/PowerShell/PowerShell/releases/latest | grep -i '^location:' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') && \
    PWSH_ARCH=$([ "${TARGETARCH}" = "amd64" ] && echo "x64" || echo "arm64") && \
    curl -sLO https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${PWSH_ARCH}.tar.gz && \
    mkdir -p /opt/microsoft/powershell/7 && \
    tar -xzf ./powershell-${PWSH_VERSION}-linux-${PWSH_ARCH}.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    rm powershell-${PWSH_VERSION}-linux-${PWSH_ARCH}.tar.gz

# Install latest Azure Powershell Modules https://learn.microsoft.com/powershell/azure/install-azps-linux
RUN test "${ADD_POWERSHELL}" = "1" || exit 0 && \
    test "${ADD_AZURE_PWSH_CLI}" = "1" || exit 0 && \
    pwsh -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; Install-Module -Name Az -Repository PSGallery -Scope AllUsers -Force;"

# Install AWS Tools for PowerShell (bundle) https://aws.amazon.com/powershell/
RUN test "${ADD_POWERSHELL}" = "1" || exit 0 && \
    test "${ADD_AWS_PWSH_CLI}" = "1" || exit 0 && \
    pwsh -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; Install-Module -Name AWSPowerShell.NetCore -Repository PSGallery -Scope AllUsers -Force;"

# Install Kubectl - https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
RUN test "${ADD_KUBECTL}" = "1" || exit 0 && \
    ARCH=$([ "$TARGETARCH" = "x64" ] && echo "amd64" || echo "arm64") && \
    curl -sLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm -f kubectl

# Install Kubelogin https://github.com/Azure/kubelogin/releases
RUN test "${ADD_KUBELOGIN}" = "1" || exit 0 && \
    ARCH=$([ "$TARGETARCH" = "x64" ] && echo "amd64" || echo "arm64") && \
    curl -sLO "https://github.com/Azure/kubelogin/releases/download/v$(curl -sI https://github.com/Azure/kubelogin/releases/latest | grep '^location:' | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+')/kubelogin-linux-${ARCH}.zip" \
    && unzip -j kubelogin-linux-${ARCH}.zip \
    && install -o root -g root -m 0755 kubelogin /usr/local/bin/kubelogin \
    && rm -f kubelogin-linux-${ARCH}.zip kubelogin

# Install YQ - https://github.com/mikefarah/yq
RUN test "${ADD_YQ}" = "1" || exit 0 && \
    ARCH=$([ "$TARGETARCH" = "x64" ] && echo "amd64" || echo "arm64") && \
    curl -sLO "https://github.com/mikefarah/yq/releases/download/v$(curl -sI https://github.com/mikefarah/yq/releases/latest | grep '^location:' | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+')/yq_linux_${ARCH}" \
    && install -o root -g root -m 0755 yq_linux_${ARCH} /usr/local/bin/yq \
    && rm -f yq_linux_${ARCH}

# Install Terraform https://developer.hashicorp.com/terraform/install
RUN test "${ADD_TERRAFORM}" = "1" || exit 0 && \
    curl -sL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/terraform-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/terraform-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/terraform.list \
    && apt update \
    && apt install -y terraform \
    && apt clean

# Install OpenTofu https://opentofu.org/docs/intro/install/
RUN test "${ADD_OPENTOFU}" = "1" || exit 0 && \
    curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | gpg --dearmor -o /usr/share/keyrings/opentofu-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/opentofu-archive-keyring.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" > /etc/apt/sources.list.d/opentofu.list \
    && apt update \
    && apt install -y tofu \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Instal Terraspace https://terraspace.cloud/docs/install/
RUN test "${ADD_TERRASPACE}" = "1" || exit 0 && \
    curl -sL https://apt.boltops.com/boltops-key.public | gpg --dearmor -o /usr/share/keyrings/boltops-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/boltops-archive-keyring.gpg] https://apt.boltops.com stable main" > /etc/apt/sources.list.d/boltops.list \
    && apt-get update \
    && apt-get install -y terraspace \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install HELM https://helm.sh/docs/intro/install/
RUN test "${ADD_HELM}" = "1" || exit 0 && \
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" > /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update \
    && apt-get install -y helm \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install Kustomize https://kubectl.docs.kubernetes.io/installation/kustomize/
RUN test "${ADD_KUSTOMIZE}" = "1" || exit 0 && \
    curl -sLf "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o /tmp/install_kustomize.sh \
    && bash /tmp/install_kustomize.sh \
    && install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize \
    && rm -f kustomize /tmp/install_kustomize.sh

# Install GitLab Runner
WORKDIR /runner
RUN RUNNER_ARCH=$([ "${TARGETARCH}" = "amd64" ] && echo "amd64" || echo "arm64") && \
    curl -LsS "https://gitlab-runner-downloads.s3.amazonaws.com/v${AGENT_VERSION}/binaries/gitlab-runner-linux-${RUNNER_ARCH}" -o /usr/local/bin/gitlab-runner && \
    chmod +x /usr/local/bin/gitlab-runner

# Agent Startup script
COPY --chmod=0755 ./start.sh .
COPY --chmod=0755 ./test-tools.sh .

# Create runner user and set up home directory
RUN useradd -m -d /home/runner runner \
    && chown -R runner:runner /runner /home/runner

USER runner

# Option to run the agent as root or not.
ENV AGENT_ALLOW_RUNASROOT="false"

ENTRYPOINT [ "./start.sh" ]