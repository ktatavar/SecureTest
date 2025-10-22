#!/bin/bash
# Publish Helm Chart to Git

set -e

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Helm Chart Publisher"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Helm is installed: $(helm version --short)${NC}"
echo ""

# Get chart version
CHART_VERSION=$(grep '^version:' helm/todo-app/Chart.yaml | awk '{print $2}')
echo "Chart version: $CHART_VERSION"
echo ""

# Menu
echo "Select publishing method:"
echo "1. Package chart locally"
echo "2. Publish to GitHub Releases"
echo "3. Publish to OCI Registry (GitHub Container Registry)"
echo "4. Create Helm Repository (GitHub Pages)"
echo "5. All of the above"
echo ""
read -p "Enter choice (1-5): " choice

case $choice in
    1|2|3|4|5)
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Step 1: Package chart
if [[ $choice =~ ^[12345]$ ]]; then
    echo ""
    echo -e "${BLUE}[1/4] Packaging Helm chart...${NC}"
    
    # Lint first
    echo "Linting chart..."
    helm lint ./helm/todo-app
    
    # Package
    cd helm
    helm package todo-app
    
    PACKAGE_FILE="todo-app-${CHART_VERSION}.tgz"
    
    if [ -f "$PACKAGE_FILE" ]; then
        echo -e "${GREEN}✅ Chart packaged: $PACKAGE_FILE${NC}"
        ls -lh "$PACKAGE_FILE"
    else
        echo -e "${RED}❌ Failed to package chart${NC}"
        exit 1
    fi
    
    cd ..
fi

# Step 2: Publish to GitHub Releases
if [[ $choice =~ ^[25]$ ]]; then
    echo ""
    echo -e "${BLUE}[2/4] Publishing to GitHub Releases...${NC}"
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}⚠️  GitHub CLI (gh) is not installed${NC}"
        echo ""
        echo "Install with:"
        echo "  brew install gh  # macOS"
        echo "  sudo apt install gh  # Linux"
        echo ""
        echo "Or manually upload to:"
        echo "  https://github.com/ktatavar/SecureTest/releases/new"
        echo "  Tag: v${CHART_VERSION}"
        echo "  Upload: helm/todo-app-${CHART_VERSION}.tgz"
    else
        # Check if authenticated
        if ! gh auth status &> /dev/null; then
            echo "Authenticating with GitHub..."
            gh auth login
        fi
        
        echo "Creating GitHub release v${CHART_VERSION}..."
        
        # Check if release exists
        if gh release view "v${CHART_VERSION}" &> /dev/null; then
            echo -e "${YELLOW}⚠️  Release v${CHART_VERSION} already exists${NC}"
            read -p "Upload chart to existing release? (yes/no): " -r
            if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                gh release upload "v${CHART_VERSION}" "helm/todo-app-${CHART_VERSION}.tgz" --clobber
                echo -e "${GREEN}✅ Chart uploaded to existing release${NC}"
            fi
        else
            gh release create "v${CHART_VERSION}" \
                "helm/todo-app-${CHART_VERSION}.tgz" \
                --title "Todo App Helm Chart v${CHART_VERSION}" \
                --notes "Helm chart for Wiz Technical Exercise Todo Application

## Installation

\`\`\`bash
# Install from GitHub release
helm install todo-app \\
  https://github.com/ktatavar/SecureTest/releases/download/v${CHART_VERSION}/todo-app-${CHART_VERSION}.tgz \\
  --create-namespace \\
  --namespace todo-app
\`\`\`

## Configuration

See [Chart README](https://github.com/ktatavar/SecureTest/blob/main/helm/todo-app/README.md) for configuration options."
            
            echo -e "${GREEN}✅ Published to GitHub Releases${NC}"
            echo "URL: https://github.com/ktatavar/SecureTest/releases/tag/v${CHART_VERSION}"
        fi
    fi
fi

# Step 3: Publish to OCI Registry
if [[ $choice =~ ^[35]$ ]]; then
    echo ""
    echo -e "${BLUE}[3/4] Publishing to OCI Registry (GHCR)...${NC}"
    
    # Check if GITHUB_TOKEN is set
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}⚠️  GITHUB_TOKEN not set${NC}"
        echo ""
        read -p "Enter GitHub Personal Access Token (or press Enter to skip): " GITHUB_TOKEN
        
        if [ -z "$GITHUB_TOKEN" ]; then
            echo "Skipping OCI registry publish"
        else
            export GITHUB_TOKEN
        fi
    fi
    
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "Logging in to GitHub Container Registry..."
        echo "$GITHUB_TOKEN" | helm registry login ghcr.io -u ktatavar --password-stdin
        
        echo "Pushing chart to OCI registry..."
        helm push "helm/todo-app-${CHART_VERSION}.tgz" oci://ghcr.io/ktatavar/securetest
        
        echo -e "${GREEN}✅ Published to OCI Registry${NC}"
        echo "Install with:"
        echo "  helm install todo-app oci://ghcr.io/ktatavar/securetest/todo-app --version ${CHART_VERSION}"
    fi
fi

# Step 4: Create Helm Repository
if [[ $choice =~ ^[45]$ ]]; then
    echo ""
    echo -e "${BLUE}[4/4] Creating Helm Repository (GitHub Pages)...${NC}"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    echo "Working in: $TEMP_DIR"
    
    # Clone gh-pages branch or create it
    if git ls-remote --heads origin gh-pages | grep -q gh-pages; then
        echo "Cloning existing gh-pages branch..."
        git clone -b gh-pages --single-branch . "$TEMP_DIR"
    else
        echo "Creating new gh-pages branch..."
        mkdir -p "$TEMP_DIR"
        cd "$TEMP_DIR"
        git init
        git checkout -b gh-pages
        git remote add origin $(git -C "$OLDPWD" config --get remote.origin.url)
        cd "$OLDPWD"
    fi
    
    # Copy chart package
    cp "helm/todo-app-${CHART_VERSION}.tgz" "$TEMP_DIR/"
    
    # Create/update index
    cd "$TEMP_DIR"
    helm repo index . --url https://ktatavar.github.io/SecureTest/ --merge index.yaml 2>/dev/null || \
        helm repo index . --url https://ktatavar.github.io/SecureTest/
    
    # Create README if it doesn't exist
    if [ ! -f README.md ]; then
        cat > README.md << 'EOF'
# SecureTest Helm Repository

Helm charts for the Wiz Technical Exercise.

## Usage

```bash
# Add repository
helm repo add securetest https://ktatavar.github.io/SecureTest/

# Update repository
helm repo update

# Search charts
helm search repo securetest

# Install chart
helm install todo-app securetest/todo-app
```

## Available Charts

- **todo-app**: Todo application with intentional security vulnerabilities
EOF
    fi
    
    # Commit and push
    git add .
    git commit -m "Update Helm chart repository - v${CHART_VERSION}" || true
    
    echo "Pushing to gh-pages branch..."
    git push origin gh-pages
    
    cd "$OLDPWD"
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}✅ Helm repository updated${NC}"
    echo ""
    echo "Users can add the repository with:"
    echo "  helm repo add securetest https://ktatavar.github.io/SecureTest/"
    echo "  helm repo update"
    echo "  helm install todo-app securetest/todo-app"
fi

# Summary
echo ""
echo "=========================================="
echo "Publishing Complete!"
echo "=========================================="
echo ""
echo "Chart: todo-app v${CHART_VERSION}"
echo ""

if [[ $choice =~ ^[12345]$ ]]; then
    echo "✅ Package: helm/todo-app-${CHART_VERSION}.tgz"
fi

if [[ $choice =~ ^[25]$ ]]; then
    echo "✅ GitHub Release: https://github.com/ktatavar/SecureTest/releases/tag/v${CHART_VERSION}"
fi

if [[ $choice =~ ^[35]$ ]] && [ -n "$GITHUB_TOKEN" ]; then
    echo "✅ OCI Registry: oci://ghcr.io/ktatavar/securetest/todo-app:${CHART_VERSION}"
fi

if [[ $choice =~ ^[45]$ ]]; then
    echo "✅ Helm Repository: https://ktatavar.github.io/SecureTest/"
fi

echo ""
echo "Installation methods:"
echo ""
echo "# From GitHub Release:"
echo "helm install todo-app https://github.com/ktatavar/SecureTest/releases/download/v${CHART_VERSION}/todo-app-${CHART_VERSION}.tgz"
echo ""
echo "# From OCI Registry:"
echo "helm install todo-app oci://ghcr.io/ktatavar/securetest/todo-app --version ${CHART_VERSION}"
echo ""
echo "# From Helm Repository:"
echo "helm repo add securetest https://ktatavar.github.io/SecureTest/"
echo "helm install todo-app securetest/todo-app"
echo ""
