#!/bin/bash

################################################################################
# Script: apim-aro-pipeline-automation.sh
# Description: Automates pipeline deployment and independent token configuration
#              between Azure API Management (APIM) and Azure Red Hat OpenShift (ARO)
# Author: AROLLMsAIServicesGBB Team
# Version: 1.0.0
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  INFO: $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS: $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

log_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

# Print section headers
print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

################################################################################
# SECTION 1: ENVIRONMENT VARIABLES CONFIGURATION
################################################################################

configure_environment_variables() {
    print_header "ENVIRONMENT VARIABLES CONFIGURATION"
    
    # Azure and ARO Configuration
    export AZ_USER="${AZ_USER:-user@example.com}"
    export AZ_RG="${AZ_RG:-aro-apim-rg}"
    export AZ_ARO="${AZ_ARO:-aro-cluster}"
    export AZ_LOCATION="${AZ_LOCATION:-eastus}"
    export UNIQUE="${UNIQUE:-$(openssl rand -hex 4)}"
    
    # APIM Configuration
    export APIM_NAME="${APIM_NAME:-apim-${UNIQUE}}"
    export APIM_PUBLISHER_EMAIL="${APIM_PUBLISHER_EMAIL:-${AZ_USER}}"
    export APIM_PUBLISHER_NAME="${APIM_PUBLISHER_NAME:-API Publisher}"
    export APIM_SKU="${APIM_SKU:-Developer}"
    export APIM_CAPACITY="${APIM_CAPACITY:-1}"
    
    # ARO/OpenShift Configuration
    export NAMESPACE="${NAMESPACE:-api-services}"
    export APP_NAME="${APP_NAME:-backend-api}"
    export APP_SERVICE="${APP_SERVICE:-${APP_NAME}-service}"
    
    # API Configuration
    export API_PATH="${API_PATH:-/api/v1}"
    export API_DISPLAY_NAME="${API_DISPLAY_NAME:-Backend API}"
    export API_DESCRIPTION="${API_DESCRIPTION:-API deployed on ARO}"
    
    # Token Configuration
    export TOKEN_ROTATION_ENABLED="${TOKEN_ROTATION_ENABLED:-true}"
    export TOKEN_EXPIRY_DAYS="${TOKEN_EXPIRY_DAYS:-90}"
    
    log_info "Environment variables configured"
    display_configuration
}

display_configuration() {
    echo ""
    echo "Current Configuration:"
    echo "====================="
    echo "Azure User: ${AZ_USER}"
    echo "Resource Group: ${AZ_RG}"
    echo "ARO Cluster: ${AZ_ARO}"
    echo "Location: ${AZ_LOCATION}"
    echo "APIM Name: ${APIM_NAME}"
    echo "APIM SKU: ${APIM_SKU}"
    echo "Namespace: ${NAMESPACE}"
    echo "App Name: ${APP_NAME}"
    echo "API Path: ${API_PATH}"
    echo "Token Rotation: ${TOKEN_ROTATION_ENABLED}"
    echo "====================="
    echo ""
}

################################################################################
# SECTION 2: PREREQUISITES CHECK
################################################################################

check_prerequisites() {
    print_header "CHECKING PREREQUISITES"
    
    local missing_tools=0
    
    # Check for required tools
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI (az) is not installed"
        missing_tools=$((missing_tools + 1))
    else
        log_success "Azure CLI found: $(az version --query '"azure-cli"' -o tsv 2>/dev/null)"
    fi
    
    if ! command -v oc &> /dev/null; then
        log_error "OpenShift CLI (oc) is not installed"
        missing_tools=$((missing_tools + 1))
    else
        log_success "OpenShift CLI found: $(oc version --client 2>/dev/null | head -1)"
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        missing_tools=$((missing_tools + 1))
    else
        log_success "jq found: $(jq --version)"
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_warning "kubectl is not installed (optional but recommended)"
    else
        log_success "kubectl found: $(kubectl version --client --short 2>/dev/null)"
    fi
    
    if [ $missing_tools -gt 0 ]; then
        log_error "Missing required tools. Please install them before continuing."
        exit 1
    fi
    
    log_success "All prerequisites met"
}

################################################################################
# SECTION 3: AZURE LOGIN AND SUBSCRIPTION SETUP
################################################################################

azure_login() {
    print_header "AZURE AUTHENTICATION"
    
    log_info "Checking Azure login status..."
    
    if ! az account show &> /dev/null; then
        log_info "Not logged in to Azure. Initiating login..."
        az login
    else
        log_success "Already logged in to Azure"
        current_account=$(az account show --query name -o tsv)
        log_info "Current subscription: ${current_account}"
    fi
    
    # List available subscriptions
    log_info "Available subscriptions:"
    az account list --query "[].{Name:name, ID:id, State:state}" -o table
    
    # Optionally set subscription
    if [ -n "${AZURE_SUBSCRIPTION_ID}" ]; then
        log_info "Setting subscription to: ${AZURE_SUBSCRIPTION_ID}"
        az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
        log_success "Subscription set successfully"
    fi
}

################################################################################
# SECTION 4: RESOURCE GROUP MANAGEMENT
################################################################################

create_resource_group() {
    print_header "RESOURCE GROUP SETUP"
    
    log_info "Checking if resource group '${AZ_RG}' exists..."
    
    if az group exists --name "${AZ_RG}" | grep -q "true"; then
        log_warning "Resource group '${AZ_RG}' already exists"
    else
        log_info "Creating resource group '${AZ_RG}' in location '${AZ_LOCATION}'..."
        az group create \
            --name "${AZ_RG}" \
            --location "${AZ_LOCATION}" \
            --output table
        
        log_success "Resource group created successfully"
    fi
}

################################################################################
# SECTION 5: AZURE API MANAGEMENT SETUP
################################################################################

create_apim_instance() {
    print_header "AZURE API MANAGEMENT SETUP"
    
    log_info "Checking if APIM instance '${APIM_NAME}' exists..."
    
    if az apim show --name "${APIM_NAME}" --resource-group "${AZ_RG}" &> /dev/null; then
        log_warning "APIM instance '${APIM_NAME}' already exists"
        return 0
    fi
    
    log_info "Creating APIM instance '${APIM_NAME}'..."
    log_warning "This may take 30-45 minutes for Developer SKU..."
    
    az apim create \
        --name "${APIM_NAME}" \
        --resource-group "${AZ_RG}" \
        --location "${AZ_LOCATION}" \
        --publisher-email "${APIM_PUBLISHER_EMAIL}" \
        --publisher-name "${APIM_PUBLISHER_NAME}" \
        --sku-name "${APIM_SKU}" \
        --sku-capacity "${APIM_CAPACITY}" \
        --no-wait
    
    log_info "APIM instance creation initiated (async)"
    log_info "Monitor progress: az apim show --name ${APIM_NAME} --resource-group ${AZ_RG} --query provisioningState -o tsv"
}

wait_for_apim_provisioning() {
    print_header "WAITING FOR APIM PROVISIONING"
    
    log_info "Waiting for APIM instance to be ready..."
    
    local max_attempts=90
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        state=$(az apim show --name "${APIM_NAME}" --resource-group "${AZ_RG}" --query provisioningState -o tsv 2>/dev/null || echo "NotFound")
        
        if [ "$state" == "Succeeded" ]; then
            log_success "APIM instance is ready"
            return 0
        elif [ "$state" == "Failed" ]; then
            log_error "APIM provisioning failed"
            return 1
        fi
        
        log_info "Current state: ${state} (attempt $((attempt + 1))/${max_attempts})"
        sleep 30
        attempt=$((attempt + 1))
    done
    
    log_error "Timeout waiting for APIM provisioning"
    return 1
}

################################################################################
# SECTION 6: ARO CLUSTER CONNECTION
################################################################################

connect_to_aro() {
    print_header "ARO CLUSTER CONNECTION"
    
    log_info "Retrieving ARO cluster credentials..."
    
    # Get ARO API server URL
    export OCP_API=$(az aro show \
        --name "${AZ_ARO}" \
        --resource-group "${AZ_RG}" \
        --query apiserverProfile.url -o tsv)
    
    if [ -z "$OCP_API" ]; then
        log_error "Failed to retrieve ARO API server URL"
        return 1
    fi
    
    log_success "ARO API Server: ${OCP_API}"
    
    # Get ARO credentials
    log_info "Retrieving ARO admin credentials..."
    ADMIN_CREDENTIALS=$(az aro list-credentials \
        --name "${AZ_ARO}" \
        --resource-group "${AZ_RG}")
    
    export OCP_USER=$(echo $ADMIN_CREDENTIALS | jq -r '.kubeadminUsername')
    export OCP_PASS=$(echo $ADMIN_CREDENTIALS | jq -r '.kubeadminPassword')
    
    # Login to OpenShift
    log_info "Logging into OpenShift cluster..."
    oc login "${OCP_API}" -u "${OCP_USER}" -p "${OCP_PASS}" --insecure-skip-tls-verify=true
    
    if [ $? -eq 0 ]; then
        log_success "Successfully logged into ARO cluster"
    else
        log_error "Failed to login to ARO cluster"
        return 1
    fi
}

################################################################################
# SECTION 7: NAMESPACE AND PROJECT SETUP
################################################################################

setup_aro_namespace() {
    print_header "ARO NAMESPACE SETUP"
    
    log_info "Checking if namespace '${NAMESPACE}' exists..."
    
    if oc get project "${NAMESPACE}" &> /dev/null; then
        log_warning "Namespace '${NAMESPACE}' already exists"
    else
        log_info "Creating namespace '${NAMESPACE}'..."
        oc new-project "${NAMESPACE}" \
            --description="API Services integrated with APIM" \
            --display-name="API Services"
        
        log_success "Namespace created successfully"
    fi
    
    # Set current project
    oc project "${NAMESPACE}"
    log_success "Current project set to '${NAMESPACE}'"
}

################################################################################
# SECTION 8: TOKEN MANAGEMENT AND SYNCHRONIZATION
################################################################################

create_service_account() {
    print_header "SERVICE ACCOUNT CREATION"
    
    local sa_name="apim-integration-sa"
    
    log_info "Creating service account '${sa_name}' in namespace '${NAMESPACE}'..."
    
    # Create service account if it doesn't exist
    if oc get sa "${sa_name}" -n "${NAMESPACE}" &> /dev/null; then
        log_warning "Service account '${sa_name}' already exists"
    else
        oc create sa "${sa_name}" -n "${NAMESPACE}"
        log_success "Service account created"
    fi
    
    # Create role binding for the service account
    log_info "Creating role binding for service account..."
    
    cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${sa_name}-binding
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: ServiceAccount
  name: ${sa_name}
  namespace: ${NAMESPACE}
EOF
    
    log_success "Role binding created"
    
    # Export service account name for later use
    export SA_NAME="${sa_name}"
}

get_service_account_token() {
    print_header "SERVICE ACCOUNT TOKEN RETRIEVAL"
    
    log_info "Retrieving service account token..."
    
    # Create a secret for the service account token (OpenShift 4.11+)
    local secret_name="${SA_NAME}-token"
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
type: kubernetes.io/service-account-token
EOF
    
    # Wait for token to be populated
    sleep 5
    
    # Get the token
    export ARO_SA_TOKEN=$(oc get secret "${secret_name}" -n "${NAMESPACE}" -o jsonpath='{.data.token}' | base64 -d)
    
    if [ -n "$ARO_SA_TOKEN" ]; then
        log_success "Service account token retrieved successfully"
        log_info "Token length: ${#ARO_SA_TOKEN} characters"
    else
        log_error "Failed to retrieve service account token"
        return 1
    fi
}

configure_apim_backend() {
    print_header "APIM BACKEND CONFIGURATION"
    
    # Get ARO public route or create one
    log_info "Getting ARO application route..."
    
    # Get the default router hostname
    export ROUTER_HOST=$(oc get route -n openshift-ingress-operator -o jsonpath='{.items[0].spec.host}' 2>/dev/null || \
                         oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.domain}')
    
    if [ -z "$ROUTER_HOST" ]; then
        log_warning "Could not determine router host automatically"
        export BACKEND_URL="https://${APP_SERVICE}-${NAMESPACE}.apps.${AZ_ARO}.${AZ_LOCATION}.aroapp.io"
    else
        export BACKEND_URL="https://${APP_SERVICE}-${NAMESPACE}.${ROUTER_HOST}"
    fi
    
    log_info "Backend URL: ${BACKEND_URL}"
    
    # Create APIM Backend
    log_info "Creating APIM backend for ARO service..."
    
    local backend_id="aro-${APP_NAME}-backend"
    
    az apim api create \
        --resource-group "${AZ_RG}" \
        --service-name "${APIM_NAME}" \
        --api-id "${backend_id}" \
        --path "${API_PATH}" \
        --display-name "${API_DISPLAY_NAME}" \
        --description "${API_DESCRIPTION}" \
        --service-url "${BACKEND_URL}" \
        --protocols https \
        --subscription-required true 2>/dev/null || {
        log_warning "API may already exist or APIM is not ready"
    }
    
    log_success "APIM backend configuration completed"
}

store_tokens_in_keyvault() {
    print_header "TOKEN STORAGE IN KEY VAULT"
    
    local keyvault_name="kv-${UNIQUE}"
    
    log_info "Creating Azure Key Vault for token storage..."
    
    # Create Key Vault if it doesn't exist
    if az keyvault show --name "${keyvault_name}" --resource-group "${AZ_RG}" &> /dev/null; then
        log_warning "Key Vault '${keyvault_name}' already exists"
    else
        az keyvault create \
            --name "${keyvault_name}" \
            --resource-group "${AZ_RG}" \
            --location "${AZ_LOCATION}" \
            --enable-rbac-authorization false \
            --output table
        
        log_success "Key Vault created"
    fi
    
    # Store ARO service account token
    log_info "Storing ARO service account token in Key Vault..."
    
    echo -n "${ARO_SA_TOKEN}" | az keyvault secret set \
        --vault-name "${keyvault_name}" \
        --name "aro-sa-token" \
        --value @- \
        --output none
    
    log_success "ARO token stored in Key Vault"
    
    # Get APIM subscription key
    log_info "Retrieving APIM subscription keys..."
    
    local subscription_key=$(az apim subscription list \
        --resource-group "${AZ_RG}" \
        --service-name "${APIM_NAME}" \
        --query "[0].primaryKey" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$subscription_key" ]; then
        echo -n "${subscription_key}" | az keyvault secret set \
            --vault-name "${keyvault_name}" \
            --name "apim-subscription-key" \
            --value @- \
            --output none
        
        log_success "APIM subscription key stored in Key Vault"
    else
        log_warning "Could not retrieve APIM subscription key"
    fi
    
    export KEYVAULT_NAME="${keyvault_name}"
}

################################################################################
# SECTION 9: PIPELINE DEPLOYMENT
################################################################################

deploy_github_actions_pipeline() {
    print_header "GITHUB ACTIONS PIPELINE DEPLOYMENT"
    
    log_info "Creating GitHub Actions workflow configuration..."
    
    local workflow_dir=".github/workflows"
    mkdir -p "${workflow_dir}"
    
    cat > "${workflow_dir}/apim-aro-cicd.yml" <<'EOF'
name: APIM-ARO CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  RESOURCE_GROUP: ${{ secrets.AZURE_RESOURCE_GROUP }}
  APIM_NAME: ${{ secrets.APIM_NAME }}
  ARO_CLUSTER: ${{ secrets.ARO_CLUSTER_NAME }}
  NAMESPACE: ${{ secrets.ARO_NAMESPACE }}

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Build Docker Image
        run: |
          docker build -t ${{ secrets.ACR_LOGIN_SERVER }}/${{ env.APP_NAME }}:${{ github.sha }} .
      
      - name: Push to ACR
        uses: azure/docker-login@v1
        with:
          login-server: ${{ secrets.ACR_LOGIN_SERVER }}
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}
      
      - name: Push image
        run: |
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/${{ env.APP_NAME }}:${{ github.sha }}
      
      - name: Login to OpenShift
        uses: redhat-actions/oc-login@v1
        with:
          openshift_server_url: ${{ secrets.OPENSHIFT_SERVER }}
          openshift_token: ${{ secrets.OPENSHIFT_TOKEN }}
          insecure_skip_tls_verify: true
      
      - name: Deploy to ARO
        run: |
          oc project ${{ env.NAMESPACE }}
          oc set image deployment/${{ env.APP_NAME }} \
            ${{ env.APP_NAME }}=${{ secrets.ACR_LOGIN_SERVER }}/${{ env.APP_NAME }}:${{ github.sha }}
          oc rollout status deployment/${{ env.APP_NAME }}
      
      - name: Update APIM Backend
        run: |
          az apim api update \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --service-name ${{ env.APIM_NAME }} \
            --api-id aro-backend-api \
            --description "Updated on $(date)"
EOF
    
    log_success "GitHub Actions workflow created at ${workflow_dir}/apim-aro-cicd.yml"
    
    # Create sample secrets documentation
    cat > "${workflow_dir}/../SECRETS.md" <<'EOF'
# Required GitHub Secrets

Configure the following secrets in your GitHub repository:

## Azure Credentials
- `AZURE_CREDENTIALS`: JSON output from `az ad sp create-for-rbac`
- `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID
- `AZURE_RESOURCE_GROUP`: Resource group name

## Azure Container Registry
- `ACR_LOGIN_SERVER`: ACR server URL
- `ACR_USERNAME`: ACR username
- `ACR_PASSWORD`: ACR password

## APIM Configuration
- `APIM_NAME`: API Management instance name

## ARO/OpenShift Configuration
- `OPENSHIFT_SERVER`: ARO API server URL
- `OPENSHIFT_TOKEN`: Service account token
- `ARO_CLUSTER_NAME`: ARO cluster name
- `ARO_NAMESPACE`: Target namespace

## Application Configuration
- `APP_NAME`: Application name
EOF
    
    log_success "Secrets documentation created at ${workflow_dir}/../SECRETS.md"
}

create_openshift_pipeline() {
    print_header "OPENSHIFT PIPELINE SETUP"
    
    log_info "Installing OpenShift Pipelines Operator (if needed)..."
    
    # Check if Pipelines operator is installed
    if oc get csv -n openshift-operators | grep -q "openshift-pipelines-operator"; then
        log_success "OpenShift Pipelines Operator already installed"
    else
        log_info "OpenShift Pipelines Operator installation required"
        log_info "Install via: OperatorHub -> OpenShift Pipelines"
    fi
    
    # Create a sample Tekton pipeline
    log_info "Creating Tekton pipeline for APIM-ARO integration..."
    
    cat <<EOF | oc apply -f -
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: apim-aro-pipeline
  namespace: ${NAMESPACE}
spec:
  params:
    - name: APP_NAME
      type: string
      description: Application name
      default: ${APP_NAME}
    - name: GIT_REPO
      type: string
      description: Git repository URL
    - name: GIT_REVISION
      type: string
      description: Git revision
      default: main
  workspaces:
    - name: shared-workspace
  tasks:
    - name: fetch-repository
      taskRef:
        name: git-clone
        kind: ClusterTask
      workspaces:
        - name: output
          workspace: shared-workspace
      params:
        - name: url
          value: \$(params.GIT_REPO)
        - name: revision
          value: \$(params.GIT_REVISION)
    
    - name: build-image
      taskRef:
        name: buildah
        kind: ClusterTask
      runAfter:
        - fetch-repository
      workspaces:
        - name: source
          workspace: shared-workspace
      params:
        - name: IMAGE
          value: image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/\$(params.APP_NAME):latest
    
    - name: deploy
      taskRef:
        name: openshift-client
        kind: ClusterTask
      runAfter:
        - build-image
      params:
        - name: SCRIPT
          value: |
            oc rollout latest dc/\$(params.APP_NAME) -n ${NAMESPACE}
            oc rollout status dc/\$(params.APP_NAME) -n ${NAMESPACE}
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Tekton pipeline created successfully"
    else
        log_warning "Could not create Tekton pipeline (operator may not be installed)"
    fi
}

################################################################################
# SECTION 10: VALIDATION AND VERIFICATION
################################################################################

validate_deployment() {
    print_header "DEPLOYMENT VALIDATION"
    
    log_info "Validating APIM instance..."
    
    local apim_state=$(az apim show \
        --name "${APIM_NAME}" \
        --resource-group "${AZ_RG}" \
        --query provisioningState -o tsv 2>/dev/null || echo "NotFound")
    
    if [ "$apim_state" == "Succeeded" ]; then
        log_success "APIM instance is healthy"
    else
        log_warning "APIM state: ${apim_state}"
    fi
    
    log_info "Validating ARO connection..."
    
    if oc whoami &> /dev/null; then
        log_success "ARO connection is active"
        log_info "Logged in as: $(oc whoami)"
    else
        log_warning "ARO connection may have issues"
    fi
    
    log_info "Checking namespace resources..."
    
    oc get all -n "${NAMESPACE}" 2>/dev/null || log_warning "No resources found in namespace"
    
    log_info "Validation complete"
}

display_summary() {
    print_header "DEPLOYMENT SUMMARY"
    
    echo "✅ Deployment completed successfully!"
    echo ""
    echo "📋 Configuration Details:"
    echo "========================="
    echo ""
    echo "🔷 Azure Resources:"
    echo "  - Resource Group: ${AZ_RG}"
    echo "  - APIM Instance: ${APIM_NAME}"
    echo "  - Key Vault: ${KEYVAULT_NAME:-Not created}"
    echo ""
    echo "🔷 ARO/OpenShift:"
    echo "  - Cluster: ${AZ_ARO}"
    echo "  - Namespace: ${NAMESPACE}"
    echo "  - API Server: ${OCP_API}"
    echo ""
    echo "🔷 Integration:"
    echo "  - Backend URL: ${BACKEND_URL:-Not configured}"
    echo "  - API Path: ${API_PATH}"
    echo "  - Service Account: ${SA_NAME:-Not created}"
    echo ""
    echo "📝 Next Steps:"
    echo "============="
    echo "1. Configure GitHub secrets (see .github/SECRETS.md)"
    echo "2. Deploy your application to namespace '${NAMESPACE}'"
    echo "3. Configure APIM policies and rate limiting"
    echo "4. Set up monitoring and alerts"
    echo "5. Test the integration end-to-end"
    echo ""
    echo "🔗 Useful Commands:"
    echo "==================="
    echo "# View APIM APIs:"
    echo "az apim api list --resource-group ${AZ_RG} --service-name ${APIM_NAME} -o table"
    echo ""
    echo "# Check ARO deployment:"
    echo "oc get all -n ${NAMESPACE}"
    echo ""
    echo "# View stored tokens:"
    echo "az keyvault secret list --vault-name ${KEYVAULT_NAME:-kv-name} -o table"
    echo ""
}

################################################################################
# SECTION 11: CLEANUP FUNCTION
################################################################################

cleanup_resources() {
    print_header "RESOURCE CLEANUP"
    
    read -p "⚠️  Are you sure you want to delete all resources? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Cleanup cancelled"
        return 0
    fi
    
    log_warning "Deleting resources..."
    
    # Delete APIM instance
    log_info "Deleting APIM instance..."
    az apim delete \
        --name "${APIM_NAME}" \
        --resource-group "${AZ_RG}" \
        --yes \
        --no-wait 2>/dev/null || log_warning "APIM not found or already deleted"
    
    # Delete ARO namespace
    log_info "Deleting ARO namespace..."
    oc delete project "${NAMESPACE}" --ignore-not-found=true 2>/dev/null || log_warning "Namespace not found"
    
    # Delete Key Vault
    if [ -n "${KEYVAULT_NAME}" ]; then
        log_info "Deleting Key Vault..."
        az keyvault delete \
            --name "${KEYVAULT_NAME}" \
            --resource-group "${AZ_RG}" 2>/dev/null || log_warning "Key Vault not found"
    fi
    
    log_success "Cleanup initiated (async operations may still be running)"
}

################################################################################
# MAIN EXECUTION FLOW
################################################################################

main() {
    print_header "APIM-ARO PIPELINE AUTOMATION"
    
    echo "This script will:"
    echo "  1. Set up Azure API Management instance"
    echo "  2. Connect to Azure Red Hat OpenShift cluster"
    echo "  3. Configure service accounts and tokens"
    echo "  4. Deploy CI/CD pipelines"
    echo "  5. Integrate APIM with ARO backend services"
    echo ""
    
    # Parse command line arguments
    case "${1:-deploy}" in
        deploy)
            configure_environment_variables
            check_prerequisites
            azure_login
            create_resource_group
            create_apim_instance
            connect_to_aro
            setup_aro_namespace
            create_service_account
            get_service_account_token
            configure_apim_backend
            store_tokens_in_keyvault
            deploy_github_actions_pipeline
            create_openshift_pipeline
            validate_deployment
            display_summary
            ;;
        
        cleanup)
            configure_environment_variables
            cleanup_resources
            ;;
        
        validate)
            configure_environment_variables
            check_prerequisites
            azure_login
            connect_to_aro
            validate_deployment
            ;;
        
        help|--help|-h)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  deploy    - Deploy and configure APIM-ARO integration (default)"
            echo "  cleanup   - Remove all created resources"
            echo "  validate  - Validate existing deployment"
            echo "  help      - Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  AZ_USER              - Azure user email"
            echo "  AZ_RG                - Azure resource group name"
            echo "  AZ_ARO               - ARO cluster name"
            echo "  AZ_LOCATION          - Azure region"
            echo "  APIM_NAME            - API Management instance name"
            echo "  NAMESPACE            - OpenShift namespace"
            echo "  APP_NAME             - Application name"
            echo ""
            exit 0
            ;;
        
        *)
            log_error "Unknown command: $1"
            log_info "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
