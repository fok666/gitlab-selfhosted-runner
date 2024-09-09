ARG BASE_VERSION=22.04
FROM --platform=linux/amd64 ubuntu:${BASE_VERSION}

ARG TARGETARCH=x64
ARG AGENT_VERSION
# ARG for optional components, defaults to 1 (enabled), set to 0 to disable
ARG ADD_DOCKER=1
ARG ADD_AZURE_CLI=1
ARG ADD_AWS_CLI=1
ARG ADD_POWERSHELL=1
ARG ADD_AZURE_PWSH_CLI=1
ARG ADD_AWS_PWSH_CLI=1
ARG ADD_KUBECTL=1
ARG ADD_KUBELOGIN=1
ARG ADD_KUSTOMIZE=1
ARG ADD_HELM=1
ARG ADD_YQ=1
ARG ADD_JQ=1
ARG ADD_TERRAFORM=1
ARG ADD_TERRASPACE=1
ARG ADD_SUDO=1

LABEL org.opencontainers.image.source=https://github.com/fok666/github-selfhosted-runner
LABEL org.opencontainers.image.description="GitHub Self-Hosted Runner"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.authors="Fernando Korndorfer"
LABEL org.opencontainers.image.version="${AGENT_VERSION}"
LABEL org.opencontainers.image.base.name="ubuntu"
LABEL org.opencontainers.image.base.version="22.04"

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
    netcat \
    iputils-ping \
    gss-ntlmssp \
    ucf \
    debsums \
    libcurl4 \
    libicu70 \
    libunwind8 \
    libxcb1 \
    libnss3 \
    libssl3 \
    libssl-dev\
    liblttng-ust-common1 \
    liblttng-ust-ctl5 \
    liblttng-ust1 \
    libkrb5-3 \
    libnuma1 \
    libdpkg-perl \
    libfile-fcntllock-perl \
    libfile-fnmatch-perl \
    liblocale-gettext-perl \
    zlib1g \
    && apt-get upgrade \
    && apt clean

# Install sudo...
RUN test "${ADD_SUDO}" = "1" || exit 0 && \
    apt-get install -y --no-install-recommends sudo \
    && apt clean \
    && echo "%agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent

# Install Docker
RUN test "${ADD_DOCKER}" = "1" || exit 0 && \
    apt-get install -y --no-install-recommends docker.io \
    && apt clean

# Install awscli
RUN test "${ADD_AWS_CLI}" = "1" || exit 0 && \
    apt-get install -y --no-install-recommends awscli \
    && apt clean

# Install jq
RUN test "${ADD_JQ}" = "1" || exit 0 && \
    apt-get install -y --no-install-recommends jq \
    && apt clean

# Install latest Azure CLI https://learn.microsoft.com/cli/azure/install-azure-cli-linux
RUN test "${ADD_AZURE_CLI}" = "1" || exit 0 && \
    curl -sLS "https://aka.ms/InstallAzureCLIDeb" | bash \
    && apt clean \
    && az config set extension.use_dynamic_install=yes_without_prompt \
    && az extension add --name azure-devops \
    && az extension add --name resource-graph

# Install latest PowerShell https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
RUN test "${ADD_POWERSHELL}" = "1" || exit 0 && \
    curl -sLO "https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    && rm -f packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell \
    && apt clean

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
    curl -sLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm -f kubectl

# Install Kubelogin https://github.com/Azure/kubelogin/releases
RUN test "${ADD_KUBELOGIN}" = "1" || exit 0 && \
    curl -sLO "https://github.com/Azure/kubelogin/releases/download/v$(curl -sI https://github.com/Azure/kubelogin/releases/latest | grep '^location:' | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+')/kubelogin-linux-amd64.zip" \
    && unzip -j kubelogin-linux-amd64.zip \
    && install -o root -g root -m 0755 kubelogin /usr/local/bin/kubelogin \
    && rm -f kubelogin-linux-amd64.zip kubelogin

# Install YQ - https://github.com/mikefarah/yq
RUN test "${ADD_YQ}" = "1" || exit 0 && \
    curl -sLO "https://github.com/mikefarah/yq/releases/download/v$(curl -sI https://github.com/mikefarah/yq/releases/latest | grep '^location:' | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+')/yq_linux_amd64" \
    && install -o root -g root -m 0755 yq_linux_amd64 /usr/local/bin/yq \
    && rm -f yq_linux_amd64

# Install Terraform https://developer.hashicorp.com/terraform/install
RUN test "${ADD_TERRAFORM}" = "1" || exit 0 && \
    curl -sL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/terraform-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/terraform-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/terraform.list \
    && apt update \
    && apt install -y terraform \
    && apt clean

# Instal Terraspace https://terraspace.cloud/docs/install/
RUN test "${ADD_TERRASPACE}" = "1" || exit 0 && \
    curl -sL https://apt.boltops.com/boltops-key.public | apt-key add - \
    && echo "deb https://apt.boltops.com stable main" > /etc/apt/sources.list.d/boltops.list \
    && apt-get update \
    && apt-get install -y terraspace \
    && apt clean

# Install HELM https://helm.sh/docs/intro/install/
RUN test "${ADD_HELM}" = "1" || exit 0 && \
    curl -sL https://baltocdn.com/helm/signing.asc | gpg --dearmor -o /usr/share/keyrings/helm.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" > /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update \
    && apt-get install helm \
    && apt clean

# Install Kustomize https://kubectl.docs.kubernetes.io/installation/kustomize/
RUN test "${ADD_KUSTOMIZE}" = "1" || exit 0 && \
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash \
    && install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize \
    && rm -f kustomize

# Install Azure DevOps Agent
WORKDIR /azp
RUN curl -LsS "https://github.com/actions/runner/releases/download/v${AGENT_VERSION}/actions-runner-linux-${TARGETARCH}-${AGENT_VERSION}.tar.gz" | tar -xz \
    && ./bin/installdependencies.sh

# Agent Startup script
COPY --chmod=0755 ./start.sh .

# Create agent user and set up home directory
RUN useradd -m -d /home/agent agent \
    && chown -R agent:agent /azp /home/agent

USER agent

# Option to run the agent as root or not.
ENV AGENT_ALLOW_RUNASROOT="false"

# ENTRYPOINT [ "./start.sh" ]
USER root
ENTRYPOINT [ "/bin/bash" ]