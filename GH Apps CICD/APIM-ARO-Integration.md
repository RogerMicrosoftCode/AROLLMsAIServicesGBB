# Azure API Management (APIM) and ARO Pipeline Automation Guide

<div align="center">
  <img src="https://docs.microsoft.com/en-us/azure/media/index/api-management.svg" height="80" alt="APIM Logo">
  &nbsp;&nbsp;&nbsp;
  <img src="https://avatars.githubusercontent.com/u/792337?s=200&v=4" height="80" alt="Red Hat OpenShift Logo">
</div>

## 📋 Overview

This comprehensive guide covers the automation of pipeline deployment and independent token configuration between **Azure API Management (APIM)** and **Azure Red Hat OpenShift (ARO)**. The solution enables secure API gateway integration with containerized applications running on OpenShift.

## 🎯 Purpose

The `apim-aro-pipeline-automation.sh` script automates the following workflows:

1. **APIM Instance Provisioning** - Deploy and configure Azure API Management
2. **ARO Integration** - Connect to existing ARO clusters
3. **Token Management** - Configure and synchronize authentication tokens
4. **Pipeline Deployment** - Set up CI/CD pipelines (GitHub Actions & OpenShift Pipelines)
5. **Backend Configuration** - Link APIM to ARO-hosted services
6. **Security** - Store credentials securely in Azure Key Vault

## 🏗️ Architecture

```
┌─────────────────┐         ┌──────────────────┐
│   API Clients   │────────▶│  Azure APIM      │
│  (External)     │         │  Gateway         │
└─────────────────┘         └────────┬─────────┘
                                     │
                                     │ Token Auth
                                     │
                            ┌────────▼─────────┐
                            │  Azure Red Hat   │
                            │   OpenShift      │
                            │   (ARO)          │
                            └──────────────────┘
                                     │
                            ┌────────▼─────────┐
                            │  Containerized   │
                            │  Applications    │
                            └──────────────────┘
```

## 📦 Prerequisites

### Required Tools

Ensure the following tools are installed:

- **Azure CLI** (v2.40.0+)
  ```bash
  az --version
  ```

- **OpenShift CLI** (v4.10+)
  ```bash
  oc version
  ```

- **jq** (JSON processor)
  ```bash
  jq --version
  ```

- **kubectl** (optional but recommended)
  ```bash
  kubectl version --client
  ```

### Azure Resources

- Active Azure subscription with Contributor access
- Existing ARO cluster (or permission to create one)
- Resource group for APIM and supporting services

### Permissions

- **Azure**: Contributor role on subscription or resource group
- **ARO**: Cluster admin access

## 🚀 Quick Start

### 1. Download the Script

```bash
# Clone the repository
git clone https://github.com/RogerMicrosoftCode/AROLLMsAIServicesGBB.git
cd AROLLMsAIServicesGBB/GH\ Apps\ CICD/

# Make the script executable
chmod +x apim-aro-pipeline-automation.sh
```

### 2. Configure Environment Variables

Set the required environment variables before running the script:

```bash
# Azure Configuration
export AZ_USER="your-email@example.com"
export AZ_RG="aro-apim-integration-rg"
export AZ_ARO="my-aro-cluster"
export AZ_LOCATION="eastus"

# APIM Configuration
export APIM_NAME="apim-production"
export APIM_PUBLISHER_EMAIL="api-admin@example.com"
export APIM_PUBLISHER_NAME="API Management Team"
export APIM_SKU="Developer"  # Options: Developer, Basic, Standard, Premium

# ARO/Application Configuration
export NAMESPACE="api-services"
export APP_NAME="backend-api"
export API_PATH="/api/v1"
export API_DISPLAY_NAME="Backend API"

# Token Configuration
export TOKEN_ROTATION_ENABLED="true"
export TOKEN_EXPIRY_DAYS="90"
```

### 3. Run the Script

```bash
# Full deployment
./apim-aro-pipeline-automation.sh deploy

# Validate existing deployment
./apim-aro-pipeline-automation.sh validate

# Cleanup resources
./apim-aro-pipeline-automation.sh cleanup

# Show help
./apim-aro-pipeline-automation.sh help
```

## 📖 Detailed Usage

### Deployment Command

The `deploy` command performs a complete setup:

```bash
./apim-aro-pipeline-automation.sh deploy
```

**This command will:**

1. ✅ Check prerequisites (Azure CLI, oc, jq)
2. ✅ Login to Azure and set subscription
3. ✅ Create or verify resource group
4. ✅ Provision APIM instance (30-45 minutes for Developer SKU)
5. ✅ Connect to ARO cluster
6. ✅ Create namespace/project in OpenShift
7. ✅ Set up service accounts and RBAC
8. ✅ Generate and retrieve service account tokens
9. ✅ Configure APIM backend pointing to ARO
10. ✅ Store tokens in Azure Key Vault
11. ✅ Deploy GitHub Actions workflow
12. ✅ Create OpenShift Pipelines (Tekton)
13. ✅ Validate the deployment
14. ✅ Display summary and next steps

### Validation Command

Verify an existing deployment:

```bash
./apim-aro-pipeline-automation.sh validate
```

This checks:
- APIM provisioning state
- ARO connection status
- Namespace resources
- Token validity

### Cleanup Command

Remove all created resources:

```bash
./apim-aro-pipeline-automation.sh cleanup
```

⚠️ **Warning**: This will delete:
- APIM instance
- ARO namespace and all resources within it
- Azure Key Vault
- Service accounts

## 🔐 Token Management

### Service Account Token Flow

1. **Creation**: Script creates a service account in the ARO namespace
2. **RBAC**: Assigns necessary permissions (edit role)
3. **Secret Generation**: Creates a token secret for the service account
4. **Retrieval**: Extracts the token value
5. **Storage**: Stores in Azure Key Vault for secure access
6. **Synchronization**: Token is used in APIM backend authentication

### Token Rotation

For production environments, implement token rotation:

```bash
# Set rotation parameters
export TOKEN_ROTATION_ENABLED="true"
export TOKEN_EXPIRY_DAYS="90"

# Script will configure tokens with expiry tracking
# Implement a cron job or scheduled task for rotation:
0 0 1 * * /path/to/apim-aro-pipeline-automation.sh deploy
```

### Accessing Stored Tokens

```bash
# List all secrets in Key Vault
az keyvault secret list --vault-name kv-<unique-id> -o table

# Retrieve ARO service account token
az keyvault secret show \
  --vault-name kv-<unique-id> \
  --name aro-sa-token \
  --query value -o tsv

# Retrieve APIM subscription key
az keyvault secret show \
  --vault-name kv-<unique-id> \
  --name apim-subscription-key \
  --query value -o tsv
```

## 🔄 CI/CD Pipeline Integration

### GitHub Actions

The script creates a complete GitHub Actions workflow at `.github/workflows/apim-aro-cicd.yml`.

#### Required GitHub Secrets

Configure these secrets in your GitHub repository (Settings → Secrets):

```
AZURE_CREDENTIALS          # Service principal credentials
AZURE_SUBSCRIPTION_ID      # Your subscription ID
AZURE_RESOURCE_GROUP       # Resource group name
APIM_NAME                  # APIM instance name
ARO_CLUSTER_NAME           # ARO cluster name
OPENSHIFT_SERVER           # ARO API server URL
OPENSHIFT_TOKEN            # Service account token
ARO_NAMESPACE              # Target namespace
ACR_LOGIN_SERVER           # Container registry URL
ACR_USERNAME               # Registry username
ACR_PASSWORD               # Registry password
```

#### Setting Up Azure Credentials

```bash
# Create a service principal
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/<resource-group> \
  --sdk-auth

# Copy the JSON output to GitHub secret: AZURE_CREDENTIALS
```

#### Workflow Triggers

The workflow triggers on:
- Push to `main` or `develop` branches
- Pull requests to `main` branch

### OpenShift Pipelines (Tekton)

The script also creates a Tekton pipeline for native OpenShift CI/CD:

```bash
# View created pipeline
oc get pipeline apim-aro-pipeline -n <namespace>

# Create a pipeline run
oc create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: apim-aro-pipeline-run-
  namespace: <namespace>
spec:
  pipelineRef:
    name: apim-aro-pipeline
  params:
    - name: APP_NAME
      value: backend-api
    - name: GIT_REPO
      value: https://github.com/yourusername/your-repo.git
    - name: GIT_REVISION
      value: main
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
EOF

# Monitor pipeline run
oc get pipelinerun -n <namespace> -w
```

## 🔧 APIM Configuration

### Backend Service Configuration

The script automatically configures APIM to point to your ARO service:

```bash
# Backend URL format
https://<app-service>-<namespace>.<router-domain>

# Example
https://backend-api-service-api-services.apps.aro-cluster.eastus.aroapp.io
```

### API Operations

After deployment, configure API operations in APIM:

```bash
# Add an operation via Azure CLI
az apim api operation create \
  --resource-group $AZ_RG \
  --service-name $APIM_NAME \
  --api-id aro-backend-api \
  --url-template "/users" \
  --method GET \
  --display-name "Get Users"

# Add request validation policy
az apim api operation policy create \
  --resource-group $AZ_RG \
  --service-name $APIM_NAME \
  --api-id aro-backend-api \
  --operation-id get-users \
  --policy-xml '<policies>
    <inbound>
      <base />
      <set-header name="Authorization" exists-action="override">
        <value>Bearer {{aro-token}}</value>
      </set-header>
    </inbound>
  </policies>'
```

### Rate Limiting

Implement rate limiting in APIM:

```xml
<policies>
  <inbound>
    <rate-limit calls="100" renewal-period="60" />
    <quota calls="10000" renewal-period="86400" />
  </inbound>
</policies>
```

## 📊 Monitoring and Observability

### APIM Monitoring

```bash
# View APIM metrics
az monitor metrics list \
  --resource $(az apim show \
    --name $APIM_NAME \
    --resource-group $AZ_RG \
    --query id -o tsv) \
  --metric Requests

# Enable Application Insights
az apim create \
  --name $APIM_NAME \
  --resource-group $AZ_RG \
  --enable-managed-identity \
  --application-insights <app-insights-resource-id>
```

### ARO Application Monitoring

```bash
# View deployment status
oc get deployment -n $NAMESPACE

# Check pod logs
oc logs -f deployment/$APP_NAME -n $NAMESPACE

# View events
oc get events -n $NAMESPACE --sort-by='.lastTimestamp'

# Monitor resource usage
oc adm top pods -n $NAMESPACE
```

## 🔍 Troubleshooting

### Common Issues

#### Issue: APIM provisioning timeout

**Solution:**
```bash
# Check provisioning state
az apim show \
  --name $APIM_NAME \
  --resource-group $AZ_RG \
  --query provisioningState

# If stuck, check Azure portal for detailed errors
```

#### Issue: Cannot connect to ARO cluster

**Solution:**
```bash
# Verify cluster is running
az aro show \
  --name $AZ_ARO \
  --resource-group $AZ_RG \
  --query provisioningState

# Get fresh credentials
az aro list-credentials \
  --name $AZ_ARO \
  --resource-group $AZ_RG

# Test connectivity
curl -k https://<api-server-url>/healthz
```

#### Issue: Service account token not generated

**Solution:**
```bash
# Check service account exists
oc get sa -n $NAMESPACE

# Manually create token secret
oc create token <service-account-name> -n $NAMESPACE --duration=87600h

# Verify secret
oc get secret -n $NAMESPACE | grep token
```

#### Issue: Backend service not accessible from APIM

**Solution:**
```bash
# Check ARO route
oc get route -n $NAMESPACE

# Test route accessibility
curl -k https://<route-url>/health

# Verify ingress controller
oc get ingresscontroller -n openshift-ingress-operator

# Check network security groups (NSGs)
az network nsg list --resource-group $AZ_RG -o table
```

### Debug Mode

Enable verbose logging:

```bash
# Add set -x at the top of the script for debugging
set -x

# Or run with bash -x
bash -x ./apim-aro-pipeline-automation.sh deploy
```

## 🔒 Security Best Practices

### 1. Network Security

```bash
# Use private endpoints for APIM
az network private-endpoint create \
  --name apim-private-endpoint \
  --resource-group $AZ_RG \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --private-connection-resource-id $(az apim show \
    --name $APIM_NAME \
    --resource-group $AZ_RG \
    --query id -o tsv) \
  --group-id Gateway \
  --connection-name apim-connection
```

### 2. RBAC Configuration

```bash
# Limit service account permissions
oc create role api-deployer \
  --verb=get,list,watch,create,update,patch \
  --resource=deployments,services,routes \
  -n $NAMESPACE

oc create rolebinding api-deployer-binding \
  --role=api-deployer \
  --serviceaccount=$NAMESPACE:apim-integration-sa \
  -n $NAMESPACE
```

### 3. Secret Management

```bash
# Use managed identities for APIM
az apim update \
  --name $APIM_NAME \
  --resource-group $AZ_RG \
  --enable-managed-identity

# Grant Key Vault access
az keyvault set-policy \
  --name $KEYVAULT_NAME \
  --object-id $(az apim show \
    --name $APIM_NAME \
    --resource-group $AZ_RG \
    --query identity.principalId -o tsv) \
  --secret-permissions get list
```

### 4. TLS/SSL Configuration

```bash
# Upload custom certificate to APIM
az apim certificate create \
  --resource-group $AZ_RG \
  --service-name $APIM_NAME \
  --certificate-id custom-cert \
  --certificate-file path/to/certificate.pfx \
  --certificate-password <password>
```

## 📚 Additional Resources

### Microsoft Documentation

- [Azure API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [Azure Red Hat OpenShift Documentation](https://docs.microsoft.com/azure/openshift/)
- [OpenShift Pipelines (Tekton)](https://docs.openshift.com/container-platform/latest/cicd/pipelines/understanding-openshift-pipelines.html)

### Example Projects

- [APIM DevOps Resource Kit](https://github.com/Azure/azure-api-management-devops-resource-kit)
- [OpenShift Examples](https://github.com/openshift/origin/tree/master/examples)

### Support

For issues or questions:
- Open an issue in this repository
- Contact the AROLLMsAIServicesGBB team
- Check [Azure Support](https://azure.microsoft.com/support/)

## 🎓 Use Cases

### E-Commerce Platform

Expose product catalog and order management APIs through APIM while running microservices on ARO.

```bash
export NAMESPACE="ecommerce"
export APP_NAME="product-catalog-api"
export API_PATH="/products/v1"
```

### Financial Services

Secure banking APIs with APIM gateway policies while leveraging ARO for PCI-compliant workloads.

```bash
export APIM_SKU="Premium"  # For VNET integration
export TOKEN_EXPIRY_DAYS="30"  # More frequent rotation
```

### Healthcare

HIPAA-compliant API gateway for patient data services.

```bash
export APIM_NAME="healthcare-apim"
export API_PATH="/patient-data/v1"
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

---

<div align="center">
  <p>© 2025 AROLLMsAIServicesGBB - Best Practices Repository</p>
  <p>
    <a href="https://github.com/RogerMicrosoftCode/AROLLMsAIServicesGBB">Repository</a> |
    <a href="https://github.com/RogerMicrosoftCode/AROLLMsAIServicesGBB/issues">Report Issues</a> |
    <a href="https://github.com/RogerMicrosoftCode/AROLLMsAIServicesGBB/blob/main/README.md">Documentation</a>
  </p>
</div>
