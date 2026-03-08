# GitHub Copilot Instructions for GitLab Self-Hosted Runner

## Project Overview

This project builds and publishes multi-profile Docker images for running **GitLab CI/CD self-hosted runners** on Linux (Ubuntu 24.04). Images are multi-architecture (amd64/arm64), built using a multi-stage Dockerfile optimized for maximum layer reusability, and published to both Docker Hub and GitHub Container Registry (GHCR).

**Key files:**

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build definition (all profiles) |
| `run.sh` | Launches N runner containers on a VM |
| `start.sh` | Entrypoint executed inside the container |
| `stop.sh` | Graceful runner deregistration |
| `test-tools.sh` | Smoke-tests installed tools at build time |
| `vmss_monitor.sh` | Handles Azure VMSS termination events |
| `ec2_monitor.sh` | Handles AWS EC2 spot-interruption notices |
| `checkRunnerVersion.sh` | Fetches latest GitLab Runner release version |
| `ARCHITECTURE.md` | Deep-dive into multi-stage build design |

## Repository Structure

```
.
├── Dockerfile              # Multi-stage build (base → common → … → profiles)
├── run.sh                  # VM-side launcher
├── start.sh                # Container entrypoint
├── stop.sh                 # Graceful shutdown / deregistration
├── test-tools.sh           # Tool smoke tests
├── vmss_monitor.sh         # Azure VMSS termination handler
├── ec2_monitor.sh          # AWS EC2 spot termination handler
├── checkRunnerVersion.sh   # Latest version helper
├── ARCHITECTURE.md         # Build architecture documentation
└── .github/
    ├── copilot-instructions.md
    ├── dependabot.yml
    └── workflows/
        ├── docker-image.yml        # Main CI: build, test, push multi-arch images
        ├── docker-hub-release.yml  # Publish release tags to Docker Hub
        ├── docker-automate.yaml    # Port.io-triggered automation workflow
        └── version-check.yml      # Scheduled upstream version checker
```

## Docker Image Profiles

| Profile | Size | Description | Included Tools |
|---------|------|-------------|----------------|
| **minimal** | ~550 MB | Essential tools only | GitLab Runner, sudo |
| **k8s** | ~850 MB | Kubernetes-focused | + Docker, kubectl, kubelogin, kustomize, Helm, jq, yq |
| **iac** | ~1.75 GB | Infrastructure as Code (bash) | + Docker, Azure CLI, AWS CLI, Terraform, OpenTofu, Terraspace, jq, yq |
| **iac-pwsh** | ~2.25 GB | IaC with PowerShell | + PowerShell (Az + AWS modules) |
| **full** | ~2.45 GB | All tools | k8s + iac-pwsh combined |

### Multi-Stage Build Layer Hierarchy

```
base (Ubuntu 24.04 + GitLab Runner)
└── common (+ sudo)
    ├── minimal  ← PROFILE
    └── docker-tools (+ Docker, jq, yq)
        ├── k8s-tools (+ kubectl, kubelogin, kustomize, Helm)
        │   └── k8s  ← PROFILE
        └── cloud-tools (+ Azure CLI, AWS CLI)
            └── iac-tools (+ Terraform, OpenTofu, Terraspace)
                ├── iac  ← PROFILE
                └── pwsh-tools (+ PowerShell + Az/AWS modules)
                    ├── iac-pwsh  ← PROFILE
                    └── full-tools (+ k8s tools copied)
                        └── full  ← PROFILE
```

## Common Commands

```bash
# Build a specific profile locally
docker build --target minimal -t gitlab-runner:minimal .
docker build --target full   -t gitlab-runner:full .

# Multi-arch build (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 --target full \
  -t ghcr.io/fok666/gitlab-selfhosted-runner:latest-full .

# Run runners on a VM (auto-detects CPU count)
./run.sh <IMAGE> <GITLAB_URL> <GITLAB_TOKEN> [TAGS] [COUNT]
# Example:
./run.sh gitlab-runner:18.7.1 https://gitlab.com glrt-xxxx "docker,linux" 4

# Check latest upstream runner version
./checkRunnerVersion.sh

# Smoke-test tools inside a running container
docker exec <CONTAINER> /test-tools.sh
```

## Architecture Patterns & Coding Standards

### Dockerfile Guidelines

- **Stage naming**: use lowercase kebab-case (`base`, `common`, `docker-tools`, etc.)
- **Final profile stages** are named after the profile: `minimal`, `k8s`, `iac`, `iac-pwsh`, `full`
- **COPY --from**: use named stages, never numeric indices
- **ARG scope**: re-declare `ARG TARGETARCH` in any stage that references it
- **Version pinning**: all tool versions are controlled via `ARG` at the top of each stage or inherited from `base`
- **Cleanup**: always end `RUN` blocks that call `apt-get` with `&& apt clean && rm -rf /var/lib/apt/lists/*`
- **Security note**: `NOPASSWD:ALL` sudo is intentional for CI/CD automation — document any changes

```dockerfile
# Pattern for adding a new tool stage
FROM docker-tools AS my-tool
ARG MY_TOOL_VERSION=1.0.0
RUN apt-get update && apt-get install -y --no-install-recommends \
    my-dependency \
    && apt clean && rm -rf /var/lib/apt/lists/*
RUN curl -LsS "https://example.com/my-tool-${MY_TOOL_VERSION}.tar.gz" | tar -xz -C /usr/local/bin
```

### Shell Script Guidelines

- Always start with `#!/bin/bash` and `set -e`
- Validate all required parameters before using them
- Provide a `USAGE_HELP` variable with a usage example
- Use `echo "Error: ..."` then `exit 1` for failures
- Auto-detect CPU count for runner/agent count; cap CPUs per runner at 2
- Use `jq` to safely construct JSON payloads (never string-concatenated JSON)

### Workflow Guidelines

- Use specific action versions (`@v6`, `@v4`, etc.) — never `@latest` or `@v1`
- Set `timeout-minutes` on all jobs
- Use `>> $GITHUB_OUTPUT` (not `set-output`) for step outputs
- Matrix strategy for multiple profiles and platforms
- PR builds: `full` profile only, both amd64 + arm64
- Push to main builds: all profiles, amd64 only (arm64 in release workflow)
- Always use `actions/checkout@v6` as first step

```yaml
# Correct output pattern
- name: Extract version
  id: ver
  run: echo "version=1.2.3" >> $GITHUB_OUTPUT

# Reference it later
- run: echo "Version is ${{ steps.ver.outputs.version }}"
```

## Test-Tools Smoke Test Pattern

`test-tools.sh` uses `command -v <tool>` guards so it is safe to run in any profile:

```bash
if command -v az &> /dev/null; then
    echo "Testing Azure CLI..."
    az version --output tsv | head -n1
    echo "Azure CLI: OK"
fi
```

When adding a new tool, add a corresponding guarded test block to `test-tools.sh`.

## Versioning & Release

- Runner version is controlled by `ARG AGENT_VERSION=<version>` in the Dockerfile
- To release a new version: update `AGENT_VERSION` in the Dockerfile **or** pass it as a workflow input/repository variable
- Image tags follow the pattern: `latest-<profile>`, `<version>-<profile>`, `<version>-<profile>-<date>`
- `checkRunnerVersion.sh` fetches the latest release from the GitLab API (no auth required)

## VMSS / EC2 Termination Handling

- `vmss_monitor.sh`: polls Azure IMDS (`169.254.169.254`) for `Terminate` scheduled events; calls `stop.sh` and acknowledges the event
- `ec2_monitor.sh`: polls AWS IMDS for spot-interruption notices; calls `stop.sh`
- `stop.sh`: deregisters the runner from GitLab and stops the container gracefully
- These scripts are designed to be called from a cron job or systemd timer on the host VM

## Common Pitfalls

- **TARGETARCH scoping**: always re-declare `ARG TARGETARCH` in each stage that maps it (e.g., `amd64 → x64 or amd64`)
- **Layer order matters**: put the heaviest, most stable layers earliest (AWS CLI, Azure CLI before Terraform)
- **Do not add tools to `base`**: the base stage is 100% shared; tool installation belongs in dedicated intermediate stages
- **Do not hardcode credentials**: use `${{ secrets.* }}` in workflows and environment variables in shell scripts
- **GHCR visibility**: the workflow pushes to `ghcr.io/<repo>` — ensure the package is set to public in GitHub settings
- **Port.io workflow** (`docker-automate.yaml`): requires `PORT_CLIENT_ID` and `PORT_CLIENT_SECRET` repository secrets

## Adding a New Tool

1. Decide which existing stage to build on (usually `docker-tools` or `cloud-tools`)
2. Create a new intermediate stage (e.g., `my-tool`)
3. Rebuild dependent profile stages using `FROM my-tool AS iac` etc.
4. Add a guarded test block in `test-tools.sh`
5. Update profile size estimates in `README.md` and `ARCHITECTURE.md`
6. Update the profile table in `README.md`

## Security Considerations

- Never open SSH in Docker images — access via `docker exec` or platform tooling
- `NOPASSWD:ALL` sudo is a conscious trade-off for CI/CD automation; document if this changes
- Use `--no-install-recommends` in all `apt-get install` calls to minimize attack surface
- Prefer downloading binaries over installing from third-party PPAs where possible
- All tokens and secrets must come from environment variables or GitHub Secrets; never bake them into images

## References

- [GitLab Runner documentation](https://docs.gitlab.com/runner/)
- [GitLab Runner Docker install](https://docs.gitlab.com/runner/install/docker.html)
- [Docker Hub: fok666/gitlab-runner](https://hub.docker.com/r/fok666/gitlab-runner)
- [GitHub Container Registry](https://ghcr.io/fok666/gitlab-selfhosted-runner)
- [Azure VMSS Scheduled Events](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/scheduled-events)
- [AWS EC2 Spot Interruption Notices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-interruptions.html)
