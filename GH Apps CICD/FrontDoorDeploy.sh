#!/bin/bash

# ============================================================
# Azure Front Door Configuration Script
# Author: Roger Oliva
# Description: Enhanced script to configure Azure Front Door
# ============================================================

set -e  # Exit if any command fails

# ============================================================
# VARIABLE CONFIGURATION
# ============================================================
export AZ_USER="rooliva@microsoft.com"
export AZ_RG="arogbbwestus3"
export AZ_ARO="aroclustergbb"
export AZ_LOCATION="westus3"
export UNIQUE="$(openssl rand -hex 4)"
export CUSTOM_DOMAIN="${AZ_USER}.apps.arolatamgbb.jaropro.net"
export APP_DOMAIN="apps.arolatamgbb.jaropro.net"
export PUBLIC_ROUTE_HOST="microsweeper-appservices-microsweeper-ex.apps.arolatamgbb.jaropro.net"
export FRONTDOOR_NAME="rooliva-microsoft-com-fd"
export ENDPOINT_NAME="rooliva-endpoint"
export ORIGIN_GROUP="rooliva-origins"
export NAMESPACE="microsweeper-ex"
export APP_SERVICE="microsweeper-appservices"

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
    
    log_success "All prerequisites validated"
}

check_resource_exists() {
    local resource_type=$1
    local resource_name=$2
    local additional_params=$3
    
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
        "custom-domain")
            az afd custom-domain show --custom-domain-name "$resource_name" --profile-name "$FRONTDOOR_NAME" --resource-group "$AZ_RG" &>/dev/null
            ;;
    esac
}

# ============================================================
# DISPLAY CONFIGURATION
# ============================================================
display_configuration() {
    echo "=================================================="
    echo "DEPLOYMENT CONFIGURATION"
    echo "=================================================="
    echo "User: ${AZ_USER}"
    echo "Resource Group: ${AZ_RG}"
    echo "ARO Cluster: ${AZ_ARO}"
    echo "Location: ${AZ_LOCATION}"
    echo "Custom Domain: ${CUSTOM_DOMAIN}"
    echo "App Domain: ${APP_DOMAIN}"
    echo "Public Route Host: ${PUBLIC_ROUTE_HOST}"
    echo "Front Door Name: ${FRONTDOOR_NAME}"
    echo "Endpoint Name: ${ENDPOINT_NAME}"
    echo "Origin Group: ${ORIGIN_GROUP}"
    echo "Namespace: ${NAMESPACE}"
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
    log_info "Creating origin 'aro-app-origin'..."
    
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
    log_info "Creating default route 'app-route'..."
    
    az afd route create \
        --route-name app-route \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --endpoint-name "$ENDPOINT_NAME" \
        --origin-group "$ORIGIN_GROUP" \
        --https-redirect enabled \
        --forwarding-protocol HttpsOnly \
        --supported-protocols Http Https \
        --link-to-default-domain Enabled
    
    log_success "Default route 'app-route' created successfully"
    
    # Display route information
    log_info "Route information:"
    az afd route show \
        --route-name app-route \
        --profile-name "$FRONTDOOR_NAME" \
        --endpoint-name "$ENDPOINT_NAME" \
        --resource-group "$AZ_RG" \
        --output table
}

create_custom_domain() {
    log_info "Checking custom domain..."
    
    if check_resource_exists "custom-domain" "app-domain"; then
        log_warning "Custom domain 'app-domain' already exists, skipping creation"
    else
        log_info "Creating custom domain 'app-domain'..."
        
        az afd custom-domain create \
            --custom-domain-name "app-domain" \
            --profile-name "$FRONTDOOR_NAME" \
            --resource-group "$AZ_RG" \
            --host-name "$APP_DOMAIN" \
            --minimum-tls-version "TLS12" \
            --certificate-type ManagedCertificate
        
        log_success "Custom domain 'app-domain' created successfully"
    fi
    
    # Get validation token
    local VALIDATION_TOKEN=$(az afd custom-domain show \
        --custom-domain-name "app-domain" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query "validationProperties.validationToken" -o tsv)
    
    echo ""
    echo "============================================================"
    echo "🔐 DOMAIN VALIDATION REQUIRED"
    echo "============================================================"
    echo "To validate domain ownership, create a TXT record:"
    echo ""
    echo "Name: _dnsauth.$APP_DOMAIN"
    echo "Value: $VALIDATION_TOKEN"
    echo "TTL: 3600"
    echo ""
    echo "============================================================"
    echo ""
}

wait_for_domain_validation() {
    echo "⏳ Waiting for custom domain validation..."
    echo "Please create the TXT record shown above and press Enter to continue..."
    read -p ""
    
    log_info "Checking domain validation status..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local VALIDATION_STATE=$(az afd custom-domain show \
            --custom-domain-name "app-domain" \
            --profile-name "$FRONTDOOR_NAME" \
            --resource-group "$AZ_RG" \
            --query "domainValidationState" -o tsv)
        
        if [[ "$VALIDATION_STATE" == "Approved" ]]; then
            log_success "Domain validated successfully!"
            return 0
        else
            log_info "Validation status: $VALIDATION_STATE (Attempt $attempt/$max_attempts)"
            if [ $attempt -lt $max_attempts ]; then
                log_info "Waiting 30 seconds before next attempt..."
                sleep 30
            fi
        fi
        
        ((attempt++))
    done
    
    log_warning "Domain is still not validated after $max_attempts attempts"
    log_warning "You can continue and check the status later"
}

create_custom_route() {
    log_info "Creating custom route 'custom-app-route'..."
    
    az afd route create \
        --route-name custom-app-route \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --endpoint-name "$ENDPOINT_NAME" \
        --origin-group "$ORIGIN_GROUP" \
        --https-redirect enabled \
        --forwarding-protocol HttpsOnly \
        --custom-domains "app-domain" \
        --supported-protocols Http Https \
        --patterns "/*"
    
    log_success "Custom route 'custom-app-route' created successfully"
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
    log_info "Custom domain status:"
    az afd custom-domain show \
        --custom-domain-name "app-domain" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query "{name:name,hostName:hostName,domainValidationState:domainValidationState,deploymentStatus:deploymentStatus}" \
        --output table
    
    echo ""
    echo "============================================================"
    echo "🎉 CONFIGURATION COMPLETED"
    echo "============================================================"
    echo "🌐 Default endpoint: https://$DEFAULT_ENDPOINT_HOST"
    echo "🔗 Custom domain: https://$APP_DOMAIN"
    echo "📱 Origin application: https://$PUBLIC_ROUTE_HOST"
    echo "============================================================"
    echo ""
    log_success "Azure Front Door configuration completed successfully!"
}

# ============================================================
# MAIN FUNCTION
# ============================================================
main() {
    echo "🚀 Starting Azure Front Door configuration..."
    echo ""
    
    # Display configuration
    display_configuration
    
    # Validate prerequisites
    validate_prerequisites
    
    # Create resources step by step
    create_frontdoor_profile
    create_frontdoor_endpoint
    create_origin_group
    create_origin
    create_default_route
    create_custom_domain
    wait_for_domain_validation
    create_custom_route
    
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