# Requirements and Configuration for Azure CLI and OpenShift Client

<div align="center">
  <img src="https://avatars.githubusercontent.com/u/6844498?s=200&v=4" alt="Azure CLI Logo" width="150"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/OpenShift-LogoType.svg/1200px-OpenShift-LogoType.svg.png" alt="OpenShift Logo" width="150"/>
   &nbsp;&nbsp;&nbsp; 
  <img src="https://logodix.com/logo/64432.png" height="150" alt="Github Logo">
</div>

This document describes the minimum requirements and configuration needed to work with Azure CLI and OpenShift Client (OC).

## 📋 Prerequisites

### System Requirements

- **Operating System**: Windows 10/11, macOS, or Linux (Ubuntu, Debian, CentOS, RHEL)
- **RAM**: Minimum 4GB (8GB recommended)
- **Disk Space**: Minimum 1GB free space
- **Internet Connection**: Required for installation and operation

### Base Software

- **Python**: Version 3.6 or higher (required for Azure CLI)
- **Node.js**: LTS version (optional, for some extensions)
- **Git**: Latest stable version

## 🔧 Azure CLI Installation

<img src="https://avatars.githubusercontent.com/u/6844498?s=200&v=4" alt="Azure CLI Logo" width="40" style="vertical-align: middle;"/> &nbsp; **Azure Command Line Interface**

### Windows

```bash
# Option 1: MSI Installer
# Download the MSI installer from: https://aka.ms/installazurecliwindows

# Option 2: PowerShell Installation
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
```

### macOS

```bash
# Install via Homebrew
brew update && brew install azure-cli

# Alternative: Install via script
curl -L https://aka.ms/InstallAzureCli | bash
```

### Linux (Ubuntu/Debian)

```bash
# Add Microsoft repository
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Azure CLI
sudo apt-get update
sudo apt-get install azure-cli
```

### Linux (RHEL/CentOS/Fedora)

```bash
# Import repository key
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

# Add repository
echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo

# Install Azure CLI
sudo dnf install azure-cli  # For Fedora/RHEL 8+
# or
sudo yum install azure-cli  # For RHEL/CentOS 7
```

### Verifying Azure CLI Installation

```bash
# Verify installation
az --version

# Login to Azure
az login
```

## 🔄 OpenShift Client (OC) Installation

<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/OpenShift-LogoType.svg/1200px-OpenShift-LogoType.svg.png" alt="OpenShift Logo" width="40" style="vertical-align: middle;"/> &nbsp; **OpenShift Command Line Interface**

### Windows

```bash
# 1. Download the OpenShift client from:
# https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/

# 2. Extract the zip file
# 3. Add oc.exe location to the PATH variable
$env:PATH += ";C:\path\to\openshift-client"
```

### macOS

```bash
# Install via Homebrew
brew install openshift-cli

# Alternative: Manual download
# 1. Download from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/
# 2. Extract and move to /usr/local/bin
tar xvzf openshift-client-mac.tar.gz
sudo mv oc /usr/local/bin
```

### Linux

```bash
# 1. Download the client
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz

# 2. Extract and move to /usr/local/bin
tar xvzf openshift-client-linux.tar.gz
sudo mv oc /usr/local/bin/
sudo mv kubectl /usr/local/bin/
```

### Verifying OpenShift Client Installation

```bash
# Verify installation
oc version

# Login to an OpenShift cluster
oc login <cluster_URL> -u <username> -p <password>
# or
oc login <cluster_URL> --token=<token>
```

## ⚙️ Basic Configuration

### Azure CLI

```bash
# Set default subscription
az account set --subscription "My Subscription"

# Configure output format
az configure --defaults output=table

# Recommended extensions
az extension add --name azure-devops
az extension add --name aks-preview
```

### OpenShift Client (OC)

```bash
# Create a new project
oc new-project my-project

# Configure default context
oc config use-context <context-name>

# Set default namespace
oc project my-project
```

## 🛠️ Additional Recommended Tools

- **kubectl**: Required to interact with Kubernetes (included with OpenShift Client)
- **Helm**: Package manager for Kubernetes
- **Docker/Podman**: For local container building and testing
- **jq**: Command-line JSON processor

## 💻 Visual Studio Code

<img src="https://code.visualstudio.com/assets/images/code-stable.png" alt="VS Code Logo" width="40" style="vertical-align: middle;"/> &nbsp; **Modern Code Editor**

### Installing Visual Studio Code

#### Windows
```bash
# Download and install from the official site
# https://code.visualstudio.com/download

# Alternative: Install with winget
winget install Microsoft.VisualStudioCode
```

#### macOS
```bash
# Install via Homebrew
brew install --cask visual-studio-code

# Alternative: Download from the official site
# https://code.visualstudio.com/download
```

#### Linux
```bash
# Ubuntu/Debian
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install code

# RHEL/Fedora/CentOS
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
sudo dnf install code
```

### Recommended VS Code Extensions

```bash
# Install from command line
code --install-extension ms-azuretools.vscode-azurefunctions
code --install-extension ms-vscode.azure-account
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension redhat.vscode-openshift-connector
code --install-extension ms-azuretools.vscode-docker
code --install-extension GitHub.vscode-pull-request-github
code --install-extension ms-vscode.PowerShell
```

- **Azure Tools**: Suite of extensions for working with Azure services
- **Kubernetes**: Provides support for Kubernetes and OpenShift
- **OpenShift Connector**: Specific for OpenShift
- **Docker**: For managing containers
- **GitHub Pull Requests and Issues**: GitHub integration
- **Azure Pipelines**: For CI/CD with Azure DevOps

## 📊 GitHub and GitHub Desktop

<img src="https://desktop.github.com/images/desktop-icon.svg" alt="GitHub Logo" width="40" style="vertical-align: middle;"/> &nbsp; **GitHub and GitHub Desktop**

### GitHub CLI

GitHub CLI (gh) is a command-line tool for interacting with GitHub from your terminal.

#### Installing GitHub CLI

##### Windows
```bash
# Install with winget
winget install GitHub.cli

# Alternative: Install with Chocolatey
choco install gh
```

##### macOS
```bash
# Install with Homebrew
brew install gh
```

##### Linux
```bash
# Ubuntu/Debian
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# RHEL/Fedora/CentOS
sudo dnf install 'dnf-command(config-manager)'
sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install gh
```

#### Basic GitHub CLI Configuration

```bash
# Authenticate with GitHub
gh auth login

# Create a new repository
gh repo create my-project --public

# Clone a repository
gh repo clone username/repository

# Create a pull request
gh pr create --title "My PR" --body "PR Description"
```

### GitHub Desktop

<img src="https://desktop.github.com/images/desktop-icon.svg" alt="GitHub Desktop Logo" width="40" style="vertical-align: middle;"/> &nbsp; **GitHub Desktop Application**

GitHub Desktop is a desktop application that simplifies your Git and GitHub workflow.

#### Installing GitHub Desktop

##### Windows and macOS
```bash
# Download and install from the official site
# https://desktop.github.com/
```

##### Linux (unofficial)
```bash
# Using the shiftkey/desktop project
sudo wget https://github.com/shiftkey/desktop/releases/download/release-3.1.1-linux1/GitHubDesktop-linux-3.1.1-linux1.deb
sudo apt install ./GitHubDesktop-linux-3.1.1-linux1.deb
```

#### Main GitHub Desktop Features

- Clone repositories with a graphical interface
- Manage branches and commits visually
- Push and pull changes
- Resolve merge conflicts
- Create and manage pull requests
- Automatic synchronization with GitHub

## 🔄 Integration Between Tools

### Integrated Workflow

1. **Development with VS Code**:
   - Edit code in VS Code with appropriate extensions
   - Use the integrated terminal for Azure CLI and OpenShift commands

2. **Version Control with GitHub**:
   - Manage repositories with GitHub CLI or GitHub Desktop
   - Implement Git workflows (branching, pull requests)

3. **Deployment to Azure/OpenShift**:
   - Use Azure CLI to provision resources in Azure
   - Deploy applications to OpenShift with OC client
   - Implement continuous integration with GitHub Actions

### Example GitHub Actions Configuration for Azure/OpenShift

```yaml
# .github/workflows/deploy.yml
name: Deploy to Azure and OpenShift

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy to Azure
        uses: azure/CLI@v1
        with:
          inlineScript: |
            az webapp deploy --resource-group myResourceGroup --name myApp --src-path ./app
      
      - name: Login to OpenShift
        uses: redhat-actions/oc-login@v1
        with:
          openshift_server_url: ${{ secrets.OPENSHIFT_SERVER }}
          openshift_token: ${{ secrets.OPENSHIFT_TOKEN }}
          insecure_skip_tls_verify: true
      
      - name: Deploy to OpenShift
        run: |
          oc project my-project
          oc apply -f kubernetes/deployment.yaml
```

## ❓ Common Troubleshooting

### Azure CLI

- **Authentication Error**: Run `az login` again or use `az account clear` followed by `az login`
- **Outdated Version**: `az upgrade` to update
- **Extension Issues**: `az extension update --name <extension-name>`

### OpenShift Client (OC)

- **Authentication Error**: Verify token with `oc whoami -t`
- **Connection Issues**: Check URL and certificate configuration
- **Insufficient Permissions**: Check roles with `oc get rolebindings`

## 📝 Important Notes

- Always keep both tools updated to the latest version
- Regularly check for changes in the official documentation
- Configure environment variables as needed
- Use secure identities and properly manage tokens and credentials

## 📚 References

- [Azure CLI Official Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [OpenShift Client Official Documentation](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- [Visual Studio Code](https://code.visualstudio.com/docs)
- [GitHub CLI](https://cli.github.com/manual/)
- [GitHub Desktop](https://docs.github.com/en/desktop)