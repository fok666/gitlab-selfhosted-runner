#!/bin/bash
set -e

echo "=== Testing GitLab Runner Tools ==="
echo "Architecture: $(uname -m)"
echo ""

# Test base tools (always installed)
echo "Testing base tools..."
git --version
curl --version | head -n1
wget --version | head -n1
echo "Base tools: OK"
echo ""

# Test optional tools
if command -v pwsh &> /dev/null; then
    echo "Testing PowerShell..."
    pwsh -Version
    echo "PowerShell: OK"
    echo ""
fi

if command -v az &> /dev/null; then
    echo "Testing Azure CLI..."
    az version --output tsv | head -n1
    echo "Azure CLI: OK"
    echo ""
fi

if command -v aws &> /dev/null; then
    echo "Testing AWS CLI..."
    aws --version
    echo "AWS CLI: OK"
    echo ""
fi

if command -v kubectl &> /dev/null; then
    echo "Testing kubectl..."
    kubectl version --client=true --output=yaml | head -n3
    echo "kubectl: OK"
    echo ""
fi

if command -v kubelogin &> /dev/null; then
    echo "Testing kubelogin..."
    kubelogin --version
    echo "kubelogin: OK"
    echo ""
fi

if command -v yq &> /dev/null; then
    echo "Testing yq..."
    yq --version
    echo "yq: OK"
    echo ""
fi

if command -v terraform &> /dev/null; then
    echo "Testing Terraform..."
    terraform version
    echo "Terraform: OK"
    echo ""
fi

if command -v tofu &> /dev/null; then
    echo "Testing OpenTofu..."
    tofu version
    echo "OpenTofu: OK"
    echo ""
fi

if command -v terraspace &> /dev/null; then
    echo "Testing Terraspace..."
    terraspace --version
    echo "Terraspace: OK"
    echo ""
fi

if command -v helm &> /dev/null; then
    echo "Testing Helm..."
    helm version
    echo "Helm: OK"
    echo ""
fi

if command -v kustomize &> /dev/null; then
    echo "Testing Kustomize..."
    kustomize version
    echo "Kustomize: OK"
    echo ""
fi

if command -v jq &> /dev/null; then
    echo "Testing jq..."
    jq --version
    echo "jq: OK"
    echo ""
fi

if command -v docker &> /dev/null; then
    echo "Testing Docker..."
    docker --version
    echo "Docker: OK"
    echo ""
fi

echo "=== All available tools tested successfully ==="
