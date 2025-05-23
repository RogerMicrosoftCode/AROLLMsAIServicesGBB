# Set the specific environment variables for this deployment
export AZ_USER="rooliva@microsoft.com"
export AZ_RG="arogbbwestus3"
export AZ_ARO="aroclustergbb"
export AZ_LOCATION="westus3"
export UNIQUE="$(openssl rand -hex 4)"

# Domain configuration
export CUSTOM_DOMAIN="${AZ_USER}.apps.arolatamgbb.jaropro.net"
export APP_DOMAIN="microsweeper-appservices-microsweeper-ex.apps.arolatamgbb.jaropro.net"
export PUBLIC_ROUTE_HOST="microsweeper-appservices-microsweeper-ex.apps.arolatamgbb.jaropro.net"

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
        --sku Standard_AzureFrontDoor
    
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
        --enabled-state Enabled
    
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

# Create Front Door profile (Standard tier recommended for WAF capabilities)
az afd profile create \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --sku Standard_AzureFrontDoor

# Create endpoint
az afd endpoint create \
  --endpoint-name $ENDPOINT_NAME \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --enabled-state Enabled

  az afd origin-group create \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --probe-request-type GET \
  --probe-protocol Http \
  --probe-path "/" \
  --probe-interval-in-seconds 60 \
  --sample-size 4 \
  --successful-samples-required 3 \
  --additional-latency-in-milliseconds 50

  az afd origin create \
  --origin-name "aro-app-origin" \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --host-name $PUBLIC_ROUTE_HOST \
  --origin-host-header $PUBLIC_ROUTE_HOST \
  --http-port 80 \
  --https-port 443 \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled

  az afd origin show \
  --origin-name "aro-app-origin" \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --output table

  az afd route create \
  --route-name app-route \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --endpoint-name $ENDPOINT_NAME \
  --origin-group $ORIGIN_GROUP \
  --https-redirect enabled \
  --forwarding-protocol HttpsOnly \
  --supported-protocols Http Https \
  --link-to-default-domain true

# Verify route creation
az afd route show \
  --route-name app-route \
  --profile-name $FRONTDOOR_NAME \
  --endpoint-name $ENDPOINT_NAME \
  --resource-group $AZ_RG \
  --output table

# Add custom domain (requires DNS validation or cert upload)
az afd custom-domain create \
  --custom-domain-name "app-domain" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --host-name $APP_DOMAIN \
  --minimum-tls-version "TLS12" \
  --certificate-type ManagedCertificate

# Get the validation token for DNS TXT record creation
VALIDATION_TOKEN=$(az afd custom-domain show \
  --custom-domain-name "app-domain" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --query "validationProperties.validationToken" -o tsv)

echo "To validate domain ownership, create a TXT record:"
echo "Name: _dnsauth.$APP_DOMAIN"
echo "Value: $VALIDATION_TOKEN"
echo "TTL: 3600"

# Wait for domain validation to complete before proceeding
echo "After creating the DNS record, wait for validation to complete..."

# Link the custom domain to the route
az afd route create \
  --route-name custom-app-route \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --endpoint-name $ENDPOINT_NAME \
  --origin-group $ORIGIN_GROUP \
  --https-redirect enabled \
  --forwarding-protocol HttpsOnly \
  --custom-domains "app-domain" \
  --supported-protocols Http Https \
  --patterns "/*"