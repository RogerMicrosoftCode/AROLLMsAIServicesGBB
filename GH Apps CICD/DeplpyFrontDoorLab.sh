#!/bin/bash

# ============================================================
# Azure Front Door Configuration Script for ARO with Default Domain
# Author: Roger Oliva
# Description: Script adapted for ARO with domain <cluster>.<region>.aroapp.io
# ============================================================

set -e  # Exit if any command fails

# ============================================================
# VARIABLE CONFIGURATION - ADAPTED FOR ARO DEFAULT DOMAIN
# ============================================================
export AZ_USER="rooliva@microsoft.com"
export AZ_RG="arogbbwestus3"
export AZ_ARO="ch0cyowl"
export AZ_LOCATION="centralus"
export UNIQUE="$(openssl rand -hex 4)"

# ⚠️ IMPORTANT CHANGE: ARO with Azure default domain
export ARO_DEFAULT_DOMAIN="${AZ_ARO}.${AZ_LOCATION}.aroapp.io"
export PUBLIC_ROUTE_HOST="microsweeper-appservice-microsweeper-ex.apps.${ARO_DEFAULT_DOMAIN}"

export FRONTDOOR_NAME="rooliva-microsoft-com-fd"
export ENDPOINT_NAME="rooliva-endpoint"
export ORIGIN_GROUP="rooliva-origins"
export NAMESPACE="microsweeper-ex"
export APP_SERVICE="microsweeper-appservice"

# ============================================================
# LOGGING FUNCTIONS
# ============================================================
log_info() {
    echo "ℹ️  $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "❌ $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warning() {
    echo "⚠️  $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# ============================================================
# VALIDATION FUNCTIONS
# ============================================================
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Verify that variables are defined
    if [[ -z "$AZ_USER" || -z "$AZ_RG" || -z "$FRONTDOOR_NAME" ]]; then
        log_error "Required variables are not defined"
        exit 1
    fi
    
    # Verify that user is logged into Azure CLI
    if ! az account show &>/dev/null; then
        log_error "You are not logged into Azure CLI. Run: az login"
        exit 1
    fi
    
    # Verify that the resource group exists
    if ! az group show --name "$AZ_RG" &>/dev/null; then
        log_error "Resource group '$AZ_RG' does not exist"
        exit 1
    fi
    
    # ⚠️ NEW: Verify that the ARO cluster exists
    if ! az aro show --name "$AZ_ARO" --resource-group "$AZ_RG" &>/dev/null; then
        log_error "ARO cluster '$AZ_ARO' does not exist in resource group '$AZ_RG'"
        exit 1
    fi
    
    # ⚠️ NEW: Verify connectivity to ARO domain
    log_info "Checking access to ARO domain: $ARO_DEFAULT_DOMAIN"
    if ! nslookup "$ARO_DEFAULT_DOMAIN" &>/dev/null; then
        log_warning "Cannot resolve ARO domain: $ARO_DEFAULT_DOMAIN"
        log_warning "This may be normal if the cluster was recently created"
    fi
    
    log_success "All prerequisites validated"
}

check_resource_exists() {
    local resource_type=$1
    local resource_name=$2
    
    case $resource_type in
        "frontdoor")
            az afd profile show --profile-name "$resource_name" --resource-group "$AZ_RG" &>/dev/null
            ;;
        "endpoint")
            az afd endpoint show --endpoint-name "$resource_name" --profile-name "$FRONTDOOR_NAME" --resource-group "$AZ_RG" &>/dev/null
            ;;
        "origin-group")
            az afd origin-group show --origin-group-name "$resource_name" --profile-name "$FRONTDOOR_NAME" --resource-group "$AZ_RG" &>/dev/null
            ;;
    esac
}

# ============================================================
# DISPLAY CONFIGURATION
# ============================================================
display_configuration() {
    echo "=================================================="
    echo "DEPLOYMENT CONFIGURATION - ARO DEFAULT DOMAIN"
    echo "=================================================="
    echo "User: ${AZ_USER}"
    echo "Resource Group: ${AZ_RG}"
    echo "ARO Cluster: ${AZ_ARO}"
    echo "Location: ${AZ_LOCATION}"
    echo "⚠️ ARO Domain (Default): ${ARO_DEFAULT_DOMAIN}"
    echo "📱 Public Route Host: ${PUBLIC_ROUTE_HOST}"
    echo "🌐 Front Door Name: ${FRONTDOOR_NAME}"
    echo "🔗 Endpoint Name: ${ENDPOINT_NAME}"
    echo "📦 Origin Group: ${ORIGIN_GROUP}"
    echo "📁 Namespace: ${NAMESPACE}"
    echo "🎯 App Service: ${APP_SERVICE}"
    echo "=================================================="
    echo "ℹ️  NOTE: Custom domain will not be configured"
    echo "ℹ️  because ARO uses Azure default domain"
    echo "ℹ️  Full URL: http://${PUBLIC_ROUTE_HOST}/"
    echo "=================================================="
    echo ""
}

# ============================================================
# MAIN FUNCTIONS
# ============================================================
create_frontdoor_profile() {
    log_info "Checking Front Door profile..."
    
    if check_resource_exists "frontdoor" "$FRONTDOOR_NAME"; then
        log_warning "Front Door profile '$FRONTDOOR_NAME' already exists, skipping creation"
        return 0
    fi
    
    log_info "Creating Front Door profile '$FRONTDOOR_NAME'..."
    
    az afd profile create \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --sku Standard_AzureFrontDoor
    
    log_success "Front Door profile '$FRONTDOOR_NAME' created successfully"
}

create_frontdoor_endpoint() {
    log_info "Checking Front Door endpoint..."
    
    if check_resource_exists "endpoint" "$ENDPOINT_NAME"; then
        log_warning "Front Door endpoint '$ENDPOINT_NAME' already exists, skipping creation"
    else
        log_info "Creating Front Door endpoint '$ENDPOINT_NAME'..."
        
        az afd endpoint create \
            --endpoint-name "$ENDPOINT_NAME" \
            --profile-name "$FRONTDOOR_NAME" \
            --resource-group "$AZ_RG" \
            --enabled-state Enabled
        
        log_success "Front Door endpoint created successfully"
    fi
    
    # Get the endpoint hostname
    export DEFAULT_ENDPOINT_HOST=$(az afd endpoint show \
        --endpoint-name "$ENDPOINT_NAME" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query hostName -o tsv)
    
    log_success "Default endpoint: https://$DEFAULT_ENDPOINT_HOST"
}

create_origin_group() {
    log_info "Checking origin group..."
    
    if check_resource_exists "origin-group" "$ORIGIN_GROUP"; then
        log_warning "Origin group '$ORIGIN_GROUP' already exists, skipping creation"
        return 0
    fi
    
    log_info "Creating origin group '$ORIGIN_GROUP'..."
    
    # ⚠️ CHANGE: Configuration for HTTP (your app uses HTTP)
    az afd origin-group create \
        --origin-group-name "$ORIGIN_GROUP" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --probe-request-type GET \
        --probe-protocol Http \
        --probe-path "/" \
        --probe-interval-in-seconds 30 \
        --sample-size 4 \
        --successful-samples-required 3 \
        --additional-latency-in-milliseconds 50
    
    log_success "Origin group '$ORIGIN_GROUP' created successfully"
}

create_origin() {
    log_info "Creating origin 'aro-app-origin' for ARO domain..."
    
    # ⚠️ IMPORTANT CHANGE: Use HTTP for ARO (your URL is HTTP)
    az afd origin create \
        --origin-name "aro-app-origin" \
        --origin-group-name "$ORIGIN_GROUP" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --host-name "$PUBLIC_ROUTE_HOST" \
        --origin-host-header "$PUBLIC_ROUTE_HOST" \
        --http-port 80 \
        --https-port 443 \
        --priority 1 \
        --weight 1000 \
        --enabled-state Enabled 
        ##--certificate-name-check-enabled Disabled
    
    log_success "Origin 'aro-app-origin' created successfully"
    
    # Display origin information
    log_info "Origin information:"
    az afd origin show \
        --origin-name "aro-app-origin" \
        --origin-group-name "$ORIGIN_GROUP" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --output table
}

create_default_route() {
    log_info "Creating default route 'aro-app-route'..."
    
    # ⚠️ CHANGE: Allow HTTP and HTTPS, your origin is HTTP
    az afd route create \
        --route-name aro-app-route \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --endpoint-name "$ENDPOINT_NAME" \
        --origin-group "$ORIGIN_GROUP" \
        --https-redirect disabled \
        --forwarding-protocol MatchRequest \
        --supported-protocols Http Https \
        --link-to-default-domain Enabled \
        --patterns "/*"
    
    log_success "Default route 'aro-app-route' created successfully"
    
    # Display route information
    log_info "Route information:"
    az afd route show \
        --route-name aro-app-route \
        --profile-name "$FRONTDOOR_NAME" \
        --endpoint-name "$ENDPOINT_NAME" \
        --resource-group "$AZ_RG" \
        --output table
}

# ⚠️ REMOVED FUNCTION: create_custom_domain() 
# Cannot be used with ARO default domains

# ⚠️ REMOVED FUNCTION: wait_for_domain_validation()
# Does not apply to ARO default domains

# ⚠️ REMOVED FUNCTION: create_custom_route()
# Not needed without custom domain

test_connectivity() {
    log_info "Testing connectivity to endpoints..."
    
    echo ""
    echo "============================================================"
    echo "🧪 CONNECTIVITY TESTS"
    echo "============================================================"
    
    # Test Front Door endpoint
    log_info "Testing Front Door endpoint..."
    if curl -s -o /dev/null -w "%{http_code}" "https://$DEFAULT_ENDPOINT_HOST" | grep -q "200\|301\|302"; then
        log_success "Front Door endpoint responds correctly"
    else
        log_warning "Front Door endpoint might not be responding yet"
    fi
    
    # Test ARO origin
    log_info "Testing original ARO application..."
    if curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_ROUTE_HOST/" | grep -q "200\|301\|302"; then
        log_success "ARO application responds correctly"
    else
        log_warning "ARO application might not be available"
    fi
    
    echo "============================================================"
}

final_verification() {
    echo ""
    echo "============================================================"
    echo "🔍 FINAL CONFIGURATION VERIFICATION"
    echo "============================================================"
    
    log_info "Endpoint information:"
    az afd endpoint show \
        --endpoint-name "$ENDPOINT_NAME" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query "{name:name,hostName:hostName,enabledState:enabledState}" \
        --output table
    
    echo ""
    log_info "Front Door profile information:"
    az afd profile show \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query "{name:name,resourceState:resourceState,sku:sku.name}" \
        --output table
    
    # Test connectivity
    test_connectivity
    
    echo ""
    echo "============================================================"
    echo "🎉 CONFIGURATION COMPLETED - ARO DEFAULT DOMAIN"
    echo "============================================================"
    echo "🌐 Front Door Endpoint: https://$DEFAULT_ENDPOINT_HOST"
    echo "📱 Original ARO Application: http://$PUBLIC_ROUTE_HOST/"
    echo "🔗 ARO Base Domain: $ARO_DEFAULT_DOMAIN"
    echo ""
    echo "⚠️  IMPORTANT:"
    echo "   • Custom domain was not configured"
    echo "   • Traffic is routed through ARO default domain"
    echo "   • For custom domain you need to control DNS"
    echo "============================================================"
    echo ""
    log_success "Azure Front Door configuration completed successfully!"
}

# ============================================================
# MAIN FUNCTION
# ============================================================
main() {
    echo "🚀 Starting Azure Front Door configuration for ARO (Default Domain)..."
    echo ""
    
    # Display configuration
    display_configuration
    
    # Validate prerequisites
    validate_prerequisites
    
    # Create resources step by step (WITHOUT custom domain)
    create_frontdoor_profile
    create_frontdoor_endpoint
    create_origin_group
    create_origin
    create_default_route
    
    # Final verification
    final_verification
    
    echo "✨ Script executed successfully!"
}

# ============================================================
# ERROR HANDLING
# ============================================================
trap 'log_error "Script interrupted at line $LINENO. Exit code: $?"' ERR

# ============================================================
# MAIN EXECUTION
# ============================================================
main "$@"