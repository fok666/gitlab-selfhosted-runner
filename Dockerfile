# ============================================================================
# Multi-Stage Dockerfile for GitLab Self-Hosted Runner
# Optimized for maximum layer reusability across profiles
# ============================================================================

# ============================================================================
# Stage 0: BASE - Common dependencies + GitLab Runner (100% shared)
# ============================================================================
FROM ubuntu:26.04 AS base

ARG TARGETARCH
ARG AGENT_VERSION=18.7.1

LABEL org.opencontainers.image.source=https://github.com/fok666/gitlab-selfhosted-runner
LABEL org.opencontainers.image.description="GitLab Self-Hosted Runner"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.authors="Fernando Korndorfer"
LABEL org.opencontainers.image.version="${AGENT_VERSION}"
LABEL org.opencontainers.image.base.name="ubuntu"
LABEL org.opencontainers.image.base.version="26.04"

USER root

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive

# Install agent dependencies - shared across ALL profiles
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
    liblttng-ust-ctl6 \
    liblttng-ust1t64 \
    libnuma1 \
    libdpkg-perl \
    libfile-fcntllock-perl \
    libfile-fnmatch-perl \
    liblocale-gettext-perl \
    && apt-get upgrade \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install GitLab Runner - shared across ALL profiles
WORKDIR /runner
RUN RUNNER_ARCH=$([ "${TARGETARCH}" = "amd64" ] && echo "amd64" || echo "arm64") && \
    curl -LsS "https://gitlab-runner-downloads.s3.amazonaws.com/v${AGENT_VERSION}/binaries/gitlab-runner-linux-${RUNNER_ARCH}" -o /usr/local/bin/gitlab-runner && \
    chmod +x /usr/local/bin/gitlab-runner

# ============================================================================
# Stage 1: COMMON - Add sudo (100% of profiles use this)
# ============================================================================
FROM base AS common

# Install sudo
# SECURITY NOTE: NOPASSWD:ALL is configured for CI/CD automation purposes.
# This allows the agent user to execute commands with sudo without password prompts.
# This is a security trade-off for CI/CD runner functionality.
RUN apt-get update && apt-get install -y --no-install-recommends sudo \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "%agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent

# ============================================================================
# Stage 2: DOCKER-TOOLS - Add Docker + common tools (80% of profiles)
# Used by: k8s, iac, iac-pwsh, full
# ============================================================================
FROM common AS docker-tools

# Install Docker and jq
RUN apt-get update && apt-get install -y --no-install-recommends \
        docker.io \
        jq \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install YQ - https://github.com/mikefarah/yq
RUN ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "amd64" || echo "arm64") && \
    curl -sLO "https://github.com/mikefarah/yq/releases/download/v$(curl -sI https://github.com/mikefarah/yq/releases/latest | grep '^location:' | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+')/yq_linux_${ARCH}" \
    && install -o root -g root -m 0755 yq_linux_${ARCH} /usr/local/bin/yq \
    && rm -f yq_linux_${ARCH}

# ============================================================================
# Stage 3a: K8S-TOOLS - Add Kubernetes tools (40% of profiles)
# Used by: k8s, full
# ============================================================================
FROM docker-tools AS k8s-tools

# Install Kubectl - https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
RUN ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "amd64" || echo "arm64") && \
    curl -sLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm -f kubectl

# Install Kubelogin https://github.com/Azure/kubelogin/releases
RUN ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "amd64" || echo "arm64") && \
    curl -sLO "https://github.com/Azure/kubelogin/releases/download/v$(curl -sI https://github.com/Azure/kubelogin/releases/latest | grep '^location:' | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+')/kubelogin-linux-${ARCH}.zip" \
    && unzip -j kubelogin-linux-${ARCH}.zip \
    && install -o root -g root -m 0755 kubelogin /usr/local/bin/kubelogin \
    && rm -f kubelogin-linux-${ARCH}.zip kubelogin

# Install Kustomize https://kubectl.docs.kubernetes.io/installation/kustomize/
RUN curl -sLf "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o /tmp/install_kustomize.sh \
    && bash /tmp/install_kustomize.sh \
    && install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize \
    && rm -f kustomize /tmp/install_kustomize.sh

# Install HELM https://helm.sh/docs/intro/install/
RUN curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" > /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update \
    && apt-get install -y helm \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Stage 3b: CLOUD-TOOLS - Add Cloud CLIs (60% of profiles)
# Used by: iac, iac-pwsh, full
# ============================================================================
FROM docker-tools AS cloud-tools

# Install AWS CLI (official installer for Ubuntu 24.04+)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Install latest Azure CLI https://learn.microsoft.com/cli/azure/install-azure-cli-linux
RUN curl -sLS "https://aka.ms/InstallAzureCLIDeb" -o /tmp/install-azure-cli.sh \
    && bash /tmp/install-azure-cli.sh \
    && rm /tmp/install-azure-cli.sh \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* \
    && az config set extension.use_dynamic_install=yes_without_prompt \
    && az extension add --name azure-devops \
    && az extension add --name resource-graph

# ============================================================================
# Stage 4: IAC-TOOLS - Add IaC tools (60% of profiles)
# Used by: iac, iac-pwsh, full
# ============================================================================
FROM cloud-tools AS iac-tools

# Install Terraform, OpenTofu, and Terraspace
# Terraform: https://developer.hashicorp.com/terraform/install
# OpenTofu: https://opentofu.org/docs/intro/install/
# Terraspace: https://terraspace.cloud/docs/install/ (amd64 only)
ARG TARGETARCH
RUN curl -sL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/terraform-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/terraform-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/terraform.list \
    && curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | gpg --dearmor -o /usr/share/keyrings/opentofu-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/opentofu-archive-keyring.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" > /etc/apt/sources.list.d/opentofu.list \
    && if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -sL https://apt.boltops.com/boltops-key.public | gpg --dearmor -o /usr/share/keyrings/boltops-archive-keyring.gpg \
        && echo "deb [signed-by=/usr/share/keyrings/boltops-archive-keyring.gpg] https://apt.boltops.com stable main" > /etc/apt/sources.list.d/boltops.list; \
    fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends terraform tofu $([ "${TARGETARCH}" = "amd64" ] && echo "terraspace") \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Stage 5: PWSH-TOOLS - Add PowerShell + modules (40% of profiles)
# Used by: iac-pwsh, full
# ============================================================================
FROM iac-tools AS pwsh-tools

# Install latest PowerShell https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
RUN PWSH_VERSION=$(curl -sI https://github.com/PowerShell/PowerShell/releases/latest | grep -i '^location:' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') && \
    PWSH_ARCH=$([ "${TARGETARCH}" = "amd64" ] && echo "x64" || echo "arm64") && \
    curl -sLO https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${PWSH_ARCH}.tar.gz && \
    mkdir -p /opt/microsoft/powershell/7 && \
    tar -xzf ./powershell-${PWSH_VERSION}-linux-${PWSH_ARCH}.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    rm powershell-${PWSH_VERSION}-linux-${PWSH_ARCH}.tar.gz

# Install latest Azure Powershell Modules https://learn.microsoft.com/powershell/azure/install-azps-linux
RUN pwsh -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; Install-Module -Name Az -Repository PSGallery -Scope AllUsers -Force;"

# Install AWS Tools for PowerShell (bundle) https://aws.amazon.com/powershell/
RUN pwsh -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; Install-Module -Name AWSPowerShell.NetCore -Repository PSGallery -Scope AllUsers -Force;"

# ============================================================================
# Stage 6: FULL-TOOLS - Combine K8s and PowerShell for full profile
# Used by: full only
# ============================================================================
FROM pwsh-tools AS full-tools

# Copy K8s tools from k8s-tools stage
COPY --from=k8s-tools /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=k8s-tools /usr/local/bin/kubelogin /usr/local/bin/kubelogin
COPY --from=k8s-tools /usr/local/bin/kustomize /usr/local/bin/kustomize
COPY --from=k8s-tools /usr/bin/helm /usr/local/bin/helm

# ============================================================================
# Stage 6b: GLAB-CLI-TOOLS - Add GitLab CLI (full profile only)
# Used by: full
# ============================================================================
FROM full-tools AS glab-cli-tools

ARG TARGETARCH
# Install GitLab CLI https://gitlab.com/gitlab-org/cli
# https://gitlab.com/gitlab-org/cli/-/releases/v1.89.0/downloads/glab_1.89.0_linux_amd64.deb
RUN GLAB_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "amd64" || echo "arm64") \
    && GLAB_VERSION=$(curl -sL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases" | grep -o '"tag_name":"v[^"]*' | head -n1 | cut -d'"' -f4 | sed 's/^v//') \
    && curl -sLO "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${GLAB_ARCH}.deb" \
    && dpkg -i "glab_${GLAB_VERSION}_linux_${GLAB_ARCH}.deb" \
    && rm "glab_${GLAB_VERSION}_linux_${GLAB_ARCH}.deb"

# ============================================================================
# FINAL STAGES - One per profile with finalization
# ============================================================================

# Profile: minimal (only base + sudo)
FROM common AS minimal
COPY --chmod=0755 ./start.sh .
COPY --chmod=0755 ./test-tools.sh .
RUN useradd -m -d /home/runner runner \
    && chown -R runner:runner /runner /home/runner
USER runner
ENV AGENT_ALLOW_RUNASROOT="false"
ENTRYPOINT [ "./start.sh" ]

# Profile: k8s (docker-tools + k8s components)
FROM k8s-tools AS k8s
COPY --chmod=0755 ./start.sh .
COPY --chmod=0755 ./test-tools.sh .
RUN useradd -m -d /home/runner runner \
    && chown -R runner:runner /runner /home/runner
USER runner
ENV AGENT_ALLOW_RUNASROOT="false"
ENTRYPOINT [ "./start.sh" ]

# Profile: iac (docker-tools + cloud-tools + iac-tools)
FROM iac-tools AS iac
COPY --chmod=0755 ./start.sh .
COPY --chmod=0755 ./test-tools.sh .
RUN useradd -m -d /home/runner runner \
    && chown -R runner:runner /runner /home/runner
USER runner
ENV AGENT_ALLOW_RUNASROOT="false"
ENTRYPOINT [ "./start.sh" ]

# Profile: iac-pwsh (iac + powershell)
FROM pwsh-tools AS iac-pwsh
COPY --chmod=0755 ./start.sh .
COPY --chmod=0755 ./test-tools.sh .
RUN useradd -m -d /home/runner runner \
    && chown -R runner:runner /runner /home/runner
USER runner
ENV AGENT_ALLOW_RUNASROOT="false"
ENTRYPOINT [ "./start.sh" ]

# Profile: full (everything - k8s + iac + powershell + gitlab cli)
FROM glab-cli-tools AS full
COPY --chmod=0755 ./start.sh .
COPY --chmod=0755 ./test-tools.sh .
RUN useradd -m -d /home/runner runner \
    && chown -R runner:runner /runner /home/runner
USER runner
ENV AGENT_ALLOW_RUNASROOT="false"
ENTRYPOINT [ "./start.sh" ]
