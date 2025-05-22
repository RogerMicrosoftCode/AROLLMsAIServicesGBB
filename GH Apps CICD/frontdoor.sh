# Set the specific environment variables for this deployment
export AZ_USER="rooliva@microsoft.com"
export AZ_RG="arogbbwestus3"
export AZ_ARO="aroclustergbb"
export AZ_LOCATION="westus3"
export UNIQUE="$(openssl rand -hex 4)"

# Domain configuration
export CUSTOM_DOMAIN="${AZ_USER}.apps.arolatamgbb.jaropro.net"
export APP_DOMAIN="microsweeper-appservices-microsweeper-ex.apps.arolatamgbb.jaropro.net"

# Front Door resources
export FRONTDOOR_NAME="rooliva-microsoft-com-fd"  # URL-safe name
export ENDPOINT_NAME="rooliva-endpoint"
export ORIGIN_GROUP="rooliva-origins"

# OpenShift configuration
export NAMESPACE="microsweeper-ex"
export APP_SERVICE="microsweeper-appservices"  # Note: using the plural form as specified

# Display configuration for verification
echo "=================================================="
echo "DEPLOYMENT CONFIGURATION"
echo "=================================================="
echo "User: ${AZ_USER}"
echo "Resource Group: ${AZ_RG}"
echo "ARO Cluster: ${AZ_ARO}"
echo "Location: ${AZ_LOCATION}"
echo "Custom Domain: ${CUSTOM_DOMAIN}"
echo "App Domain: ${APP_DOMAIN}"
echo "Front Door Name: ${FRONTDOOR_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "=================================================="


# Create Front Door profile and endpoint
create_frontdoor_profile() {
    echo "🚀 Creating Azure Front Door profile..."
    
    # Create Front Door profile
    az afd profile create \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --sku Standard_AzureFrontDoor \
        --location "$AZ_LOCATION"
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create Front Door profile"
        return 1
    fi
    
    echo "✅ Front Door profile '$FRONTDOOR_NAME' created successfully"
    
    # Create Front Door endpoint
    echo "🌐 Creating Front Door endpoint..."
    az afd endpoint create \
        --endpoint-name "$ENDPOINT_NAME" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --enabled true
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create Front Door endpoint"
        return 1
    fi
    
    # Get the default endpoint hostname
    export DEFAULT_ENDPOINT_HOST=$(az afd endpoint show \
        --endpoint-name "$ENDPOINT_NAME" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query hostName -o tsv)
    
    echo "✅ Front Door endpoint created successfully"
    echo "🌐 Default endpoint: https://$DEFAULT_ENDPOINT_HOST"
}

# Create the Front Door profile and endpoint
create_frontdoor_profile