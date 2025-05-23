# Azure Front Door Integration with Azure Red Hat OpenShift (ARO)

This guide demonstrates how to expose applications running on an Azure Red Hat OpenShift (ARO) cluster using Azure Front Door. We'll cover both public and private cluster scenarios with detailed step-by-step instructions.

## Overview

Azure Front Door is a global, scalable entry-point that uses the Microsoft global edge network to create fast, secure, and highly scalable web applications. When integrated with ARO, it provides several benefits:

* **Enhanced Security**: WAF and DDoS protection, certificate management, and SSL offloading
* **Global Edge Access**: Traffic is controlled at Microsoft's edge before entering your Azure environment
* **Private Infrastructure**: Your ARO cluster and Azure resources can remain private even when services are publicly accessible

## Architecture

![ARO + Azure Front Door Diagram](images/aro-frontdoor.png)

In this architecture:
- Azure Front Door sits at the edge of Microsoft's network
- Traffic is routed through Azure Front Door to your ARO cluster
- For private clusters, Front Door connects via an Azure Private Link service
- For public clusters, Front Door can connect directly to public endpoints

## Prerequisites

- An Azure Red Hat OpenShift (ARO) cluster (public or private)
- Access to Azure CLI and OpenShift CLI (oc)
- A deployed application on the ARO cluster (like the microsweeper app from the workshop)
- Administrative access to your Azure subscription

## Environment Variables Setup

Before starting with Azure Front Door deployment, we need to set up the necessary environment variables. These variables will be used throughout the implementation process.

### Core Environment Variables

```bash
# Set these variables according to your environment
export AZ_USER="<your-username>"            # Your assigned username (e.g., user1)
export AZ_RG="${AZ_USER}-rg"                # Resource group name
export AZ_ARO="${AZ_USER}-cluster"          # ARO cluster name
export AZ_LOCATION="eastus"                 # Azure region
export UNIQUE="$(openssl rand -hex 4)"      # Unique identifier for resources

# Domain and Front Door variables
export CUSTOM_DOMAIN="${AZ_USER}.example.com"  # Your custom domain
export FRONTDOOR_NAME="${AZ_USER}-fd"          # Name for Front Door profile
export ENDPOINT_NAME="${AZ_USER}-endpoint"     # Front Door endpoint name
export ORIGIN_GROUP="${AZ_USER}-origins"       # Origin group name

# OpenShift variables
export NAMESPACE="microsweeper-ex"             # Application namespace
export APP_SERVICE="microsweeper-appservice"   # Application service name
export APP_DOMAIN="app.${AZ_USER}.example.com" # App subdomain
```

### OpenShift Login and Project Configuration

Before working with your ARO cluster, you need to authenticate and set the correct project context:

#### Step 1: Get OpenShift Credentials and URLs

```bash
# Get OpenShift console URL
export OCP_CONSOLE="$(az aro show --name ${AZ_ARO} \
  --resource-group ${AZ_RG} \
  -o tsv --query consoleProfile)"

# Get OpenShift API server URL
export OCP_API="$(az aro show --name ${AZ_ARO} \
  --resource-group ${AZ_RG} \
  --query apiserverProfile.url -o tsv)"

# Get cluster credentials (admin)
ADMIN_CREDENTIALS=$(az aro list-credentials \
  --name "${AZ_ARO}" \
  --resource-group "${AZ_RG}")

export OCP_USER=$(echo $ADMIN_CREDENTIALS | jq -r '.kubeadminUsername')
export OCP_PASS=$(echo $ADMIN_CREDENTIALS | jq -r '.kubeadminPassword')

# Display the information
echo "=================================================="
echo "OPENSHIFT CLUSTER INFORMATION"
echo "=================================================="
echo "Console URL: ${OCP_CONSOLE}"
echo "API Server: ${OCP_API}"
echo "Username: ${OCP_USER}"
echo "Password: ${OCP_PASS}"
echo "=================================================="
```

#### Step 2: Login to OpenShift CLI

```bash
# Login to OpenShift using the CLI
echo "🔐 Logging into OpenShift cluster..."
oc login "${OCP_API}" -u "${OCP_USER}" -p "${OCP_PASS}"

# Verify login was successful
if [ $? -eq 0 ]; then
    echo "✅ Successfully logged into OpenShift cluster"
    echo "Current user: $(oc whoami)"
    echo "Current server: $(oc whoami --show-server)"
else
    echo "❌ Failed to login to OpenShift cluster"
    echo "Please verify the credentials and try again"
    exit 1
fi
```

#### Step 3: Set Up Project/Namespace

```bash
# Check if the project exists
if oc get project $NAMESPACE >/dev/null 2>&1; then
    echo "📁 Project '$NAMESPACE' already exists"
    oc project $NAMESPACE
else
    echo "📁 Creating new project '$NAMESPACE'..."
    oc new-project $NAMESPACE --description="Microsweeper application for Front Door integration"
fi

# Verify current project context
CURRENT_PROJECT=$(oc project -q)
echo "Current project: $CURRENT_PROJECT"

if [ "$CURRENT_PROJECT" != "$NAMESPACE" ]; then
    echo "⚠️  Warning: Current project ($CURRENT_PROJECT) does not match expected project ($NAMESPACE)"
    echo "Switching to correct project..."
    oc project $NAMESPACE
fi

echo "✅ Project setup completed successfully"
```

#### Alternative: Login with Token (More Secure for Automation)

For automation scripts or CI/CD pipelines, using tokens is more secure:

```bash
# Alternative method: Login with token
login_with_token() {
    echo "🔐 Logging into OpenShift with token..."
    
    # Get token from the console or use a service account token
    if [ -z "$OCP_TOKEN" ]; then
        echo "📋 To get a token, visit: ${OCP_CONSOLE}"
        echo "   1. Login to the web console"
        echo "   2. Click on your username (top right)"
        echo "   3. Select 'Copy Login Command'"
        echo "   4. Copy the token from the command"
        echo ""
        read -p "Enter your OpenShift token: " OCP_TOKEN
    fi
    
    # Login with token
    oc login --token="$OCP_TOKEN" --server="$OCP_API"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully logged in with token"
    else
        echo "❌ Failed to login with token"
        return 1
    fi
}

# Uncomment the line below to use token-based authentication
# login_with_token
```

#### Step 4: Verify Cluster Access and Permissions

```bash
# Verify cluster access and permissions
echo "🔍 Verifying cluster access and permissions..."

# Check if we can list projects
echo "Available projects:"
oc get projects | head -10

# Check permissions in current project
echo ""
echo "Permissions in current project ($NAMESPACE):"
oc auth can-i --list --namespace=$NAMESPACE | head -10

# Check if we can create resources
echo ""
echo "Testing resource creation permissions:"
oc auth can-i create pods --namespace=$NAMESPACE && echo "✅ Can create pods" || echo "❌ Cannot create pods"
oc auth can-i create services --namespace=$NAMESPACE && echo "✅ Can create services" || echo "❌ Cannot create services"
oc auth can-i create routes --namespace=$NAMESPACE && echo "✅ Can create routes" || echo "❌ Cannot create routes"
oc auth can-i create secrets --namespace=$NAMESPACE && echo "✅ Can create secrets" || echo "❌ Cannot create secrets"

echo ""
echo "🎉 Cluster verification completed"
```

#### Complete Login Script

```bash
#!/bin/bash

# Complete OpenShift login and setup script
setup_openshift_access() {
    echo "🚀 Setting up OpenShift access..."
    
    # Verify required variables are set
    if [ -z "$AZ_USER" ] || [ -z "$AZ_RG" ] || [ -z "$AZ_ARO" ]; then
        echo "❌ Required environment variables not set. Please run:"
        echo "   export AZ_USER='your-username'"
        echo "   export AZ_RG='your-resource-group'"
        echo "   export AZ_ARO='your-cluster-name'"
        return 1
    fi
    
    # Step 1: Get cluster information
    echo "📡 Getting cluster information..."
    export OCP_CONSOLE="$(az aro show --name ${AZ_ARO} --resource-group ${AZ_RG} -o tsv --query consoleProfile)"
    export OCP_API="$(az aro show --name ${AZ_ARO} --resource-group ${AZ_RG} --query apiserverProfile.url -o tsv)"
    
    # Check if cluster exists and is accessible
    if [ -z "$OCP_API" ] || [ "$OCP_API" == "null" ]; then
        echo "❌ Could not retrieve cluster information. Verify cluster exists and you have access."
        return 1
    fi
    
    # Step 2: Get credentials
    echo "🔑 Getting cluster credentials..."
    ADMIN_CREDENTIALS=$(az aro list-credentials --name "${AZ_ARO}" --resource-group "${AZ_RG}")
    export OCP_USER=$(echo $ADMIN_CREDENTIALS | jq -r '.kubeadminUsername')
    export OCP_PASS=$(echo $ADMIN_CREDENTIALS | jq -r '.kubeadminPassword')
    
    # Step 3: Login to cluster
    echo "🔐 Logging into cluster..."
    oc login "${OCP_API}" -u "${OCP_USER}" -p "${OCP_PASS}" --insecure-skip-tls-verify=true
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to login to OpenShift cluster"
        return 1
    fi
    
    # Step 4: Setup project
    echo "📁 Setting up project..."
    if ! oc get project $NAMESPACE >/dev/null 2>&1; then
        oc new-project $NAMESPACE --description="Microsweeper application for Azure Front Door integration"
    else
        oc project $NAMESPACE
    fi
    
    # Step 5: Verify setup
    echo "✅ OpenShift setup completed successfully!"
    echo ""
    echo "📋 Summary:"
    echo "   Cluster: $OCP_API"
    echo "   User: $(oc whoami)"
    echo "   Project: $(oc project -q)"
    echo "   Console: $OCP_CONSOLE"
    echo ""
    
    # Save configuration for later use
    cat << EOF > ~/.openshift_config
# OpenShift configuration for Azure Front Door workshop
export OCP_CONSOLE="${OCP_CONSOLE}"
export OCP_API="${OCP_API}"
export OCP_USER="${OCP_USER}"
export OCP_PASS="${OCP_PASS}"
export NAMESPACE="${NAMESPACE}"
EOF
    
    echo "💾 Configuration saved to ~/.openshift_config"
    echo "   You can source this file in future sessions: source ~/.openshift_config"
}

# Run the setup
setup_openshift_access
```

#### Troubleshooting OpenShift Login Issues

```bash
# Common troubleshooting commands
troubleshoot_openshift_login() {
    echo "🔍 Troubleshooting OpenShift login issues..."
    
    # Check if Azure CLI is working
    echo "1. Verifying Azure CLI access..."
    az account show --output table
    
    # Check if cluster exists
    echo "2. Verifying cluster exists..."
    az aro show --name "${AZ_ARO}" --resource-group "${AZ_RG}" --output table
    
    # Check cluster status
    echo "3. Checking cluster status..."
    CLUSTER_STATE=$(az aro show --name "${AZ_ARO}" --resource-group "${AZ_RG}" --query provisioningState -o tsv)
    echo "Cluster provisioning state: $CLUSTER_STATE"
    
    if [ "$CLUSTER_STATE" != "Succeeded" ]; then
        echo "⚠️  Cluster is not in 'Succeeded' state. Current state: $CLUSTER_STATE"
        echo "   Wait for cluster provisioning to complete before attempting login."
    fi
    
    # Test network connectivity to API server
    echo "4. Testing network connectivity to API server..."
    if [ -n "$OCP_API" ]; then
        echo "API Server: $OCP_API"
        curl -k -s --connect-timeout 10 "$OCP_API/version" > /dev/null
        if [ $? -eq 0 ]; then
            echo "✅ Can reach API server"
        else
            echo "❌ Validation rejected. Verify DNS configuration."
            return 1
            ;;
        *)
            echo "❓ Unknown status: $status"
            return 1
            ;;
    esac
}

# Verify validation (may take a few minutes)
echo "Verifying domain validation..."
if check_domain_validation; then
    echo "Proceeding with route configuration..."
else
    echo "Wait for domain validation to complete before continuing."
    echo "You can manually verify the TXT record with: nslookup -type=TXT _dnsauth.${APP_DOMAIN}"
fi
```

##### Step 5: Create route with custom domain

```bash
# Create route associated with custom domain
az afd route create \
  --route-name custom-app-route \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --endpoint-name $ENDPOINT_NAME \
  --origin-group $ORIGIN_GROUP \
  --https-redirect enabled \
  --forwarding-protocol HttpsOnly \
  --custom-domains "my-app-domain" \
  --supported-protocols Http Https \
  --patterns "/*"

# Verify custom route creation
az afd route show \
  --route-name custom-app-route \
  --profile-name $FRONTDOOR_NAME \
  --endpoint-name $ENDPOINT_NAME \
  --resource-group $AZ_RG \
  --output json | jq '.customDomains'
```

#### SSL/TLS Certificate Configuration

Azure Front Door automatically handles SSL certificates, but it's important to understand the options:

##### Azure Managed Certificates (Recommended)

```bash
# Verify managed certificate status
az afd custom-domain show \
  --custom-domain-name "my-app-domain" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --query "{domain: hostName, certType: certificateType, certStatus: certificateStatus}" \
  --output table

# Azure managed certificates renew automatically
echo "✅ Azure managed certificates renew automatically"
echo "✅ No manual intervention required"
echo "✅ Include automatic domain validation"
```

##### Own Certificates (Advanced)

If you prefer to use your own certificates:

```bash
# First, upload your certificate to Azure Key Vault
# Then use it in the custom domain
az afd custom-domain create \
  --custom-domain-name "my-app-domain-own-cert" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --host-name "secure.mycompany.com" \
  --minimum-tls-version "TLS12" \
  --certificate-type CustomerCertificate \
  --certificate-url "https://my-keyvault.vault.azure.net/certificates/my-certificate/version"

echo "⚠️  With own certificates, you're responsible for:"
echo "   - Renewal before expiration"
echo "   - Certificate chain management"
echo "   - Key Vault access permissions"
```

#### Complete Domain Configuration Script

```bash
#!/bin/bash

# Script to configure domain (automatic or custom)
configure_domain() {
    local domain_type=$1
    
    case $domain_type in
        "auto"|"automatic")
            echo "🚀 Configuring automatic domain..."
            
            # Use automatic domain
            az afd route create \
                --route-name app-route-auto \
                --profile-name $FRONTDOOR_NAME \
                --resource-group $AZ_RG \
                --endpoint-name $ENDPOINT_NAME \
                --origin-group $ORIGIN_GROUP \
                --https-redirect enabled \
                --forwarding-protocol HttpsOnly \
                --supported-protocols Http Https \
                --link-to-default-domain true \
                --patterns "/*"
            
            echo "✅ Configuration completed!"
            echo "🌐 Your application is available at: https://${DEFAULT_ENDPOINT_HOST}"
            ;;
            
        "custom"|"personal")
            echo "🚀 Configuring custom domain..."
            
            # Request domain from user if not defined
            if [ -z "$APP_DOMAIN" ]; then
                read -p "Enter your custom domain (e.g. app.mycompany.com): " APP_DOMAIN
            fi
            
            # Create custom domain
            az afd custom-domain create \
                --custom-domain-name "my-app-domain" \
                --profile-name $FRONTDOOR_NAME \
                --resource-group $AZ_RG \
                --host-name $APP_DOMAIN \
                --minimum-tls-version "TLS12" \
                --certificate-type ManagedCertificate
            
            # Show DNS instructions
            VALIDATION_TOKEN=$(az afd custom-domain show \
                --custom-domain-name "my-app-domain" \
                --profile-name $FRONTDOOR_NAME \
                --resource-group $AZ_RG \
                --query "validationProperties.validationToken" -o tsv)
            
            echo ""
            echo "📋 REQUIRED DNS CONFIGURATION:"
            echo "================================"
            echo "1. TXT record (for validation):"
            echo "   Name: _dnsauth.${APP_DOMAIN}"
            echo "   Value: ${VALIDATION_TOKEN}"
            echo ""
            echo "2. CNAME record (for traffic):"
            echo "   Name: ${APP_DOMAIN}"
            echo "   Value: ${DEFAULT_ENDPOINT_HOST}"
            echo "================================"
            echo ""
            echo "⏳ After configuring DNS, run:"
            echo "   ./configure_domain.sh validate"
            ;;
            
        "validate")
            echo "🔍 Validating custom domain..."
            
            # Verify validation
            if check_domain_validation; then
                # Create route with custom domain
                az afd route create \
                    --route-name custom-app-route \
                    --profile-name $FRONTDOOR_NAME \
                    --resource-group $AZ_RG \
                    --endpoint-name $ENDPOINT_NAME \
                    --origin-group $ORIGIN_GROUP \
                    --https-redirect enabled \
                    --forwarding-protocol HttpsOnly \
                    --custom-domains "my-app-domain" \
                    --supported-protocols Http Https \
                    --patterns "/*"
                
                echo "✅ Configuration completed!"
                echo "🌐 Your application is available at: https://${APP_DOMAIN}"
            else
                echo "❌ Validation not yet completed."
                echo "   Verify DNS configuration and try again in a few minutes."
            fi
            ;;
            
        *)
            echo "Usage: $0 {auto|custom|validate}"
            echo "  auto     - Use Azure automatic domain"
            echo "  custom   - Configure custom domain"
            echo "  validate - Validate and activate custom domain"
            ;;
    esac
}

# Example usage:
# configure_domain "auto"     # For automatic domain
# configure_domain "custom"   # For custom domain
# configure_domain "validate" # To validate custom domain
```

#### Comparison: Automatic vs Custom Domain

| Feature | Automatic Domain | Custom Domain |
|---------|------------------|---------------|
| **Setup time** | Immediate | 15-60 minutes |
| **DNS configuration** | Not required | Required (TXT + CNAME) |
| **SSL certificate** | Included automatically | Included (Azure managed) |
| **Cost** | Included | Included |
| **Customization** | Limited | Complete |
| **Easy to remember** | Difficult | Easy |
| **Suitable for** | Development/Testing | Production |
| **Example URL** | `my-app.z01.azurefd.net` | `app.mycompany.com` |

#### Best Practices for Domains

1. **For development**: Use automatic domain for quick setup
2. **For production**: Always use custom domains
3. **DNS configuration**: Use low TTL (300-600s) during initial setup
4. **Certificates**: Prefer Azure managed certificates for simplicity
5. **Subdomains**: Consider using specific subdomains (app.mycompany.com, api.mycompany.com)
6. **Monitoring**: Set up alerts for certificate expiration (though Azure renews automatically)

### 5. Configure Route in OpenShift

Create a route that uses your custom domain:

```bash
cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  labels:
    app.kubernetes.io/name: microsweeper-appservice
    app.kubernetes.io/version: 1.0.0-SNAPSHOT
    app.openshift.io/runtime: quarkus
    type: private  # Only needed for private ingress controller
  name: microsweeper-appservice-fd
  namespace: microsweeper-ex
spec:
  host: $APP_DOMAIN
  to:
    kind: Service
    name: microsweeper-appservice
    weight: 100
    targetPort:
      port: 8080
  wildcardPolicy: None
EOF
```

### 6. Configure DNS

Update your DNS to point your custom domain to the Azure Front Door endpoint:

```bash
# Get the Front Door endpoint hostname
FRONTDOOR_ENDPOINT=$(az afd endpoint show \
  --endpoint-name $ENDPOINT_NAME \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --query hostName -o tsv)

# Create a CNAME record in your DNS provider
# CNAME $APP_DOMAIN -> $FRONTDOOR_ENDPOINT
```

### 7. Web Application Firewall (WAF) Configuration

To protect your application with WAF:

```bash
# Create WAF policy
az network front-door waf-policy create \
  --name "${AZ_USER}-waf-policy" \
  --resource-group $AZ_RG \
  --mode Detection \
  --sku Standard_AzureFrontDoor

# Enable OWASP rule set
az network front-door waf-policy managed-rules add \
  --policy-name "${AZ_USER}-waf-policy" \
  --resource-group $AZ_RG \
  --type DefaultRuleSet \
  --version 1.1

# Associate WAF policy with your custom domain
az afd security-policy create \
  --security-policy-name "${AZ_USER}-security-policy" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --domains my-app-domain \
  --waf-policy "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$AZ_RG/providers/Microsoft.Network/frontdoorWebApplicationFirewallPolicies/${AZ_USER}-waf-policy"
```

**Detailed explanation:**
- **--mode**: Sets WAF operation mode.
  - **Detection**: Only detects and logs threats without blocking.
  - **Prevention**: Actively blocks detected threats.
- **--type DefaultRuleSet**: Uses the default OWASP rule set.
- **--version**: OWASP rule set version to use.

### 8. Cache Configuration

To improve performance, configure cache rules:

```bash
# Add cache configuration to your route
az afd route update \
  --route-name app-route \
  --profile-name $FRONTDOOR_NAME \
  --endpoint-name $ENDPOINT_NAME \
  --resource-group $AZ_RG \
  --cache-configuration query-string-caching=IncludeSpecifiedQueryStrings query-parameters='version' compression=Enabled cache-duration=1.12:00:00
```

**Detailed explanation:**
- **query-string-caching**: Defines how to handle query parameters for caching.
- **query-parameters**: List of query parameters to include in cache key.
- **compression**: Enables content compression to improve performance.
- **cache-duration**: Cache duration (in this example, 1 day and 12 hours).

### 9. Configuration Verification

Once configuration is complete, verify everything works correctly:

```bash
# Test default Front Door endpoint
curl -Ik https://$DEFAULT_ENDPOINT_HOST

# Test with custom domain (after DNS configuration)
curl -Ik https://$APP_DOMAIN

# Verify DNS resolution
nslookup $APP_DOMAIN
```

**Common troubleshooting:**

1. **Custom domain doesn't work**:
   - Verify DNS records (TXT and CNAME) are correctly configured
   - Verify domain validation completed in Azure Front Door

2. **502 Bad Gateway errors**:
   - Verify application is running at the origin
   - Verify ports and protocols are correctly configured

3. **SSL certificate issues**:
   - Wait 1-2 hours for managed certificate to be provisioned
   - Verify domain validation status

4. **Cache not working as expected**:
   - Review Cache-Control headers configuration in your application
   - Verify query parameters are configured correctly

## Differences Between Public and Private ARO Clusters

| Feature | Public ARO Cluster | Private ARO Cluster |
|---------|-------------------|---------------------|
| Ingress Controller | Uses default public ingress | Requires private ingress controller |
| Connectivity | Direct from Front Door to public endpoints | Requires Private Link Service |
| Default Security | Traffic flows over public internet to ARO | Traffic remains on Microsoft backbone |
| Implementation | Simpler, fewer components | More complex, more secure |
| Variable Requirements | PUBLIC_ROUTE_HOST | PRIVATE_LINK_SERVICE_ID |
| Route Configuration | Standard route | Route with private link backend |
| Network Configuration | No additional network setup | Requires proper VNet and subnet configuration |
| DNS Requirements | Direct DNS to public endpoints | DNS to Front Door endpoints only |

## Testing the Configuration

Verify your setup with these steps:

```bash
# Get your custom domain from the route
DOMAIN=$(oc -n microsweeper-ex get route microsweeper-appservice-fd -o jsonpath='{.spec.host}')

# Verify DNS resolution
nslookup $DOMAIN

# Check the connection in your browser
echo "Visit https://$DOMAIN in your browser"
```

When visiting your custom domain in a browser, you should see:
1. A secure connection (HTTPS)
2. Your application loading successfully
3. Traffic routed through Azure Front Door (visible in DNS lookup as references to *.azurefd.net and *.t-msedge.net)

## Benefits of This Approach

- **Security**: Azure Front Door provides WAF capabilities to protect against common web exploits
- **Performance**: Global content delivery and edge caching improve application performance
- **Scalability**: Front Door automatically scales with traffic demands
- **Certificate Management**: Managed TLS certificates with automatic renewal
- **Traffic Management**: Load balancing and health probes ensure high availability

## Troubleshooting

If your application is not accessible through Azure Front Door, follow these troubleshooting steps:

### 1. Verify Ingress Controller Status

```bash
# For public clusters, check the default ingress controller
oc -n openshift-ingress-operator get ingresscontroller default -o yaml

# For private clusters, check the private ingress controller
oc -n openshift-ingress-operator get ingresscontroller private -o yaml

# Check if ingress pods are running
oc -n openshift-ingress get pods
```

### 2. Check Route Configuration

```bash
# Verify the route exists and has correct host
oc -n $NAMESPACE get route $APP_SERVICE-fd -o yaml

# Test direct access to the route (should work for public clusters)
curl -Ik https://$(oc -n $NAMESPACE get route $APP_SERVICE -o jsonpath='{.spec.host}')
```

### 3. Verify DNS Configuration

```bash
# Check DNS resolution for your custom domain
nslookup $APP_DOMAIN

# Make sure it resolves to Azure Front Door (should see azurefd.net in the chain)
dig $APP_DOMAIN +trace

# Verify TXT record for domain validation
nslookup -type=TXT _dnsauth.$APP_DOMAIN
```

### 4. Check Azure Front Door Configuration

```bash
# Verify origin group health
az afd origin-group show \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG

# Check origin health
az afd origin show \
  --origin-name "aro-app-origin" \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG

# Verify route configuration
az afd route show \
  --route-name app-route \
  --profile-name $FRONTDOOR_NAME \
  --endpoint-name $ENDPOINT_NAME \
  --resource-group $AZ_RG

# For private clusters, check private link status
az network private-endpoint-connection list \
  --resource-group $AZ_RG \
  --output table
```

### 5. Test with cURL

```bash
# Test the default Front Door endpoint
curl -Ik https://$DEFAULT_ENDPOINT_HOST

# Test with custom domain
curl -Ik https://$APP_DOMAIN
```

### 6. Check WAF Rules and Logs

If you've configured WAF policies, check if they're blocking legitimate traffic:

```bash
# List WAF policies
az network front-door waf-policy list --resource-group $AZ_RG -o table

# Check WAF logs in Azure Monitor/Log Analytics
# Navigate to Azure Portal -> Front Door profile -> Diagnostics -> Logs
```

### 7. Common Issues and Solutions

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| 502 Bad Gateway | Origin unreachable | Check if app is running and accessible from origin |
| 403 Forbidden | WAF rule blocking | Review and adjust WAF rules |
| Connection timeout | DNS misconfiguration | Verify CNAME records are correct |
| Certificate errors | Domain validation incomplete | Check validation status in Front Door |
| Intermittent failures | Health probe failures | Adjust probe settings, check app health |
| Private link issues | Access request not approved | Approve private endpoint connection |

## Advanced Configuration Options

### Implementing Web Application Firewall (WAF)

Azure Front Door can be configured with a WAF policy to protect your applications from common web threats:

```bash
# Create a WAF policy
az network front-door waf-policy create \
  --name "${AZ_USER}-waf-policy" \
  --resource-group $AZ_RG \
  --mode Detection \
  --sku Standard_AzureFrontDoor

# Enable OWASP rule set
az network front-door waf-policy managed-rules add \
  --policy-name "${AZ_USER}-waf-policy" \
  --resource-group $AZ_RG \
  --type DefaultRuleSet \
  --version 1.1

# Associate WAF policy with your Front Door security policy
az afd security-policy create \
  --security-policy-name "${AZ_USER}-security-policy" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --domains my-app-domain \
  --waf-policy "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$AZ_RG/providers/Microsoft.Network/frontdoorWebApplicationFirewallPolicies/${AZ_USER}-waf-policy"
```

### Setting Up Geographic Filtering

You can configure geographic filtering to allow or block traffic from specific countries:

```bash
# Create a custom rule for geo-filtering
az network front-door waf-policy custom-rules add \
  --policy-name "${AZ_USER}-waf-policy" \
  --resource-group $AZ_RG \
  --name "BlockCountries" \
  --priority 100 \
  --rule-type MatchRule \
  --action Block \
  --match-condition-operator GeoMatch \
  --match-values "XX" "YY" \  # Replace with country codes to block
  --match-variable RemoteAddr
```

### Setting Up Caching Rules

To improve performance, configure caching rules:

```bash
# Add caching configuration to your route
az afd route update \
  --route-name app-route \
  --profile-name $FRONTDOOR_NAME \
  --endpoint-name $ENDPOINT_NAME \
  --resource-group $AZ_RG \
  --cache-configuration query-string-caching=IncludeSpecifiedQueryStrings query-parameters='version' compression=Enabled cache-duration=1.12:00:00  # 1 day 12 hours
```

## GitHub Actions Workflow for Automation

You can automate the deployment of your application and Front Door configuration using GitHub Actions. Here's a sample workflow file:

```yaml
name: Deploy App to ARO with Front Door

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
          
      - name: Set up OpenShift CLI
        uses: redhat-actions/openshift-tools-installer@v1
        with:
          oc: latest
          
      - name: OpenShift Login
        run: |
          oc login --token=${{ secrets.OPENSHIFT_TOKEN }} --server=${{ secrets.OPENSHIFT_SERVER }}
          
      - name: Deploy Application
        run: |
          cd ./app
          # Add deployment commands here
          
      - name: Configure Azure Front Door
        run: |
          # Add Front Door configuration commands here
          # Use variables stored in GitHub secrets
```

## Practical Implementation: Deploying Azure Front Door with Specific Environment

This section provides a step-by-step implementation using specific environment variables for a real Azure Red Hat OpenShift cluster deployment.

### Environment Configuration for This Implementation

```bash
# Set the specific environment variables for this deployment
export AZ_USER="rooliva@microsoft.com"
export AZ_RG="arogbbwestus3"
export AZ_ARO="aroclustergbb"
export AZ_LOCATION="westus3o"
export UNIQUE="$(openssl rand -hex 4)"

# Domain configuration
export CUSTOM_DOMAIN="${AZ_USER}.apps.arolatamgbb.jaropro.net"
export APP_DOMAIN="rooliva00.apps.arolatamgbb.jaropro.net"

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
```

### Step 1: Validate Environment and Login

```bash
#!/bin/bash

# Validation and login script
validate_and_login() {
    echo "🔍 Validating environment..."
    
    # Check if Azure CLI is logged in
    if ! az account show >/dev/null 2>&1; then
        echo "❌ Not logged into Azure CLI. Please run 'az login'"
        return 1
    fi
    
    echo "✅ Azure CLI authenticated"
    
    # Verify the resource group exists
    if ! az group show --name "$AZ_RG" >/dev/null 2>&1; then
        echo "❌ Resource group '$AZ_RG' not found"
        return 1
    fi
    
    echo "✅ Resource group '$AZ_RG' found"
    
    # Verify the ARO cluster exists
    CLUSTER_STATE=$(az aro show --name "$AZ_ARO" --resource-group "$AZ_RG" --query provisioningState -o tsv 2>/dev/null)
    if [ -z "$CLUSTER_STATE" ]; then
        echo "❌ ARO cluster '$AZ_ARO' not found in resource group '$AZ_RG'"
        return 1
    elif [ "$CLUSTER_STATE" != "Succeeded" ]; then
        echo "⚠️  ARO cluster state: $CLUSTER_STATE (expected: Succeeded)"
        echo "   Please wait for cluster provisioning to complete"
        return 1
    fi
    
    echo "✅ ARO cluster '$AZ_ARO' is ready (state: $CLUSTER_STATE)"
    
    # Get OpenShift credentials
    echo "🔑 Getting OpenShift credentials..."
    export OCP_CONSOLE="$(az aro show --name ${AZ_ARO} --resource-group ${AZ_RG} -o tsv --query consoleProfile)"
    export OCP_API="$(az aro show --name ${AZ_ARO} --resource-group ${AZ_RG} --query apiserverProfile.url -o tsv)"
    
    ADMIN_CREDENTIALS=$(az aro list-credentials --name "${AZ_ARO}" --resource-group "${AZ_RG}")
    export OCP_USER=$(echo $ADMIN_CREDENTIALS | jq -r '.kubeadminUsername')
    export OCP_PASS=$(echo $ADMIN_CREDENTIALS | jq -r '.kubeadminPassword')
    
    echo "🔐 Logging into OpenShift..."
    oc login "${OCP_API}" -u "${OCP_USER}" -p "${OCP_PASS}" --insecure-skip-tls-verify=true
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to login to OpenShift cluster"
        return 1
    fi
    
    # Setup project
    if ! oc get project $NAMESPACE >/dev/null 2>&1; then
        echo "📁 Creating project '$NAMESPACE'..."
        oc new-project $NAMESPACE --description="Microsweeper application for Azure Front Door integration"
    else
        echo "📁 Using existing project '$NAMESPACE'..."
        oc project $NAMESPACE
    fi
    
    echo "✅ Environment validation and login completed successfully"
    return 0
}

# Run validation
validate_and_login
```

### Step 2: Get Application Route Information

```bash
# Get the existing application route
get_app_route_info() {
    echo "🔍 Getting application route information..."
    
    # Check if the application service exists
    if ! oc get service $APP_SERVICE -n $NAMESPACE >/dev/null 2>&1; then
        echo "❌ Service '$APP_SERVICE' not found in namespace '$NAMESPACE'"
        echo "   Available services:"
        oc get services -n $NAMESPACE
        return 1
    fi
    
    echo "✅ Service '$APP_SERVICE' found"
    
    # Get existing route if it exists
    EXISTING_ROUTE=$(oc get route -n $NAMESPACE -l app.kubernetes.io/name=${APP_SERVICE} -o jsonpath='{.items[0].spec.host}' 2>/dev/null)
    
    if [ -n "$EXISTING_ROUTE" ]; then
        export PUBLIC_ROUTE_HOST="$EXISTING_ROUTE"
        echo "✅ Found existing route: $PUBLIC_ROUTE_HOST"
    else
        echo "⚠️  No existing route found. Creating one..."
        
        # Create a route for the application
        cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  labels:
    app.kubernetes.io/name: ${APP_SERVICE}
  name: ${APP_SERVICE}
  namespace: ${NAMESPACE}
spec:
  to:
    kind: Service
    name: ${APP_SERVICE}
    weight: 100
  port:
    targetPort: 8080
  wildcardPolicy: None
EOF
        
        # Wait for route to be created and get hostname
        sleep 5
        export PUBLIC_ROUTE_HOST=$(oc get route $APP_SERVICE -n $NAMESPACE -o jsonpath='{.spec.host}')
        echo "✅ Created new route: $PUBLIC_ROUTE_HOST"
    fi
    
    # Test route accessibility
    echo "🧪 Testing route accessibility..."
    curl -Ik https://$PUBLIC_ROUTE_HOST --connect-timeout 10
    
    if [ $? -eq 0 ]; then
        echo "✅ Route is accessible"
    else
        echo "⚠️  Route may not be fully ready yet"
    fi
}

# Get application route information
get_app_route_info
```

### Step 3: Create Azure Front Door Profile and Endpoint

```bash
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
```

### Step 4: Configure Origin Group and Origin

```bash
# Configure origin group and origin
configure_origin() {
    echo "🎯 Creating origin group..."
    
    # Create origin group with health probe settings
    az afd origin-group create \
        --origin-group-name "$ORIGIN_GROUP" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --probe-request-type GET \
        --probe-protocol Https \
        --probe-path "/" \
        --probe-interval-in-seconds 60 \
        --sample-size 4 \
        --successful-samples-required 3 \
        --additional-latency-in-milliseconds 50
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create origin group"
        return 1
    fi
    
    echo "✅ Origin group '$ORIGIN_GROUP' created successfully"
    
    # Create origin pointing to the ARO application route
    echo "🎯 Creating origin for ARO application..."
    az afd origin create \
        --origin-name "aro-microsweeper-origin" \
        --origin-group-name "$ORIGIN_GROUP" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --host-name "$PUBLIC_ROUTE_HOST" \
        --origin-host-header "$PUBLIC_ROUTE_HOST" \
        --http-port 80 \
        --https-port 443 \
        --priority 1 \
        --weight 1000 \
        --enabled true
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create origin"
        return 1
    fi
    
    echo "✅ Origin 'aro-microsweeper-origin' created successfully"
    echo "🎯 Origin points to: $PUBLIC_ROUTE_HOST"
}

# Configure the origin
configure_origin
```

### Step 5: Create Route for Default Domain

```bash
# Create route for the default domain
create_default_route() {
    echo "🛤️  Creating route for default domain..."
    
    az afd route create \
        --route-name "microsweeper-default-route" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --endpoint-name "$ENDPOINT_NAME" \
        --origin-group "$ORIGIN_GROUP" \
        --https-redirect enabled \
        --forwarding-protocol HttpsOnly \
        --supported-protocols Http Https \
        --link-to-default-domain true \
        --patterns "/*"
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create default route"
        return 1
    fi
    
    echo "✅ Default route created successfully"
    echo "🌐 Application accessible at: https://$DEFAULT_ENDPOINT_HOST"
    
    # Test the default endpoint
    echo "🧪 Testing default endpoint..."
    sleep 30  # Wait for propagation
    curl -Ik https://$DEFAULT_ENDPOINT_HOST --connect-timeout 15
}

# Create the default route
create_default_route
```

### Step 6: Configure Custom Domain (Optional)

```bash
# Configure custom domain
configure_custom_domain() {
    echo "🌍 Configuring custom domain: $APP_DOMAIN"
    
    # Create custom domain
    az afd custom-domain create \
        --custom-domain-name "microsweeper-custom-domain" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --host-name "$APP_DOMAIN" \
        --minimum-tls-version "TLS12" \
        --certificate-type ManagedCertificate
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create custom domain"
        return 1
    fi
    
    # Get validation token
    VALIDATION_TOKEN=$(az afd custom-domain show \
        --custom-domain-name "microsweeper-custom-domain" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query "validationProperties.validationToken" -o tsv)
    
    echo "✅ Custom domain created"
    echo ""
    echo "=================================================="
    echo "DNS CONFIGURATION REQUIRED"
    echo "=================================================="
    echo "🔧 Add these DNS records in your DNS provider:"
    echo ""
    echo "1. TXT Record for domain validation:"
    echo "   Name: _dnsauth.${APP_DOMAIN}"
    echo "   Value: ${VALIDATION_TOKEN}"
    echo "   TTL: 3600"
    echo ""
    echo "2. CNAME Record for traffic routing:"
    echo "   Name: rooliva00"
    echo "   Value: ${DEFAULT_ENDPOINT_HOST}"
    echo "   TTL: 3600"
    echo "=================================================="
    echo ""
    echo "⏳ After configuring DNS, run the validation step"
}

# Configure custom domain (uncomment to use)
# configure_custom_domain
```

### Step 7: Validate Custom Domain and Create Custom Route

```bash
# Validate custom domain and create route
validate_and_create_custom_route() {
    echo "🔍 Validating custom domain..."
    
    # Check domain validation status
    local status=$(az afd custom-domain show \
        --custom-domain-name "microsweeper-custom-domain" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query "domainValidationState" -o tsv 2>/dev/null)
    
    echo "Domain validation status: $status"
    
    if [ "$status" != "Approved" ]; then
        echo "⚠️  Domain not yet validated. Current status: $status"
        echo "   Please ensure DNS records are configured and try again later"
        return 1
    fi
    
    echo "✅ Domain validated successfully"
    
    # Create route with custom domain
    az afd route create \
        --route-name "microsweeper-custom-route" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --endpoint-name "$ENDPOINT_NAME" \
        --origin-group "$ORIGIN_GROUP" \
        --https-redirect enabled \
        --forwarding-protocol HttpsOnly \
        --custom-domains "microsweeper-custom-domain" \
        --supported-protocols Http Https \
        --patterns "/*"
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create custom route"
        return 1
    fi
    
    echo "✅ Custom route created successfully"
    echo "🌐 Application accessible at: https://$APP_DOMAIN"
}

# Validate and create custom route (run after DNS configuration)
# validate_and_create_custom_route
```

### Step 8: Configure OpenShift Route for Front Door

```bash
# Configure OpenShift route for Front Door
configure_openshift_route() {
    echo "🛤️  Configuring OpenShift route for Front Door..."
    
    # Create route that accepts traffic from Front Door custom domain
    cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  labels:
    app.kubernetes.io/name: ${APP_SERVICE}
    app.kubernetes.io/version: 1.0.0-SNAPSHOT
    app.openshift.io/runtime: quarkus
    type: frontdoor
  name: ${APP_SERVICE}-frontdoor
  namespace: ${NAMESPACE}
spec:
  host: ${APP_DOMAIN}
  to:
    kind: Service
    name: ${APP_SERVICE}
    weight: 100
  port:
    targetPort: 8080
  wildcardPolicy: None
EOF

    if [ $? -eq 0 ]; then
        echo "✅ OpenShift route for Front Door created successfully"
        echo "🌐 Route configured for domain: $APP_DOMAIN"
    else
        echo "❌ Failed to create OpenShift route for Front Door"
        return 1
    fi
}

# Configure OpenShift route
configure_openshift_route
```

### Step 9: Configure WAF (Web Application Firewall)

```bash
# Configure WAF for enhanced security
configure_waf() {
    echo "🛡️  Configuring Web Application Firewall..."
    
    # Create WAF policy
    WAF_POLICY_NAME="rooliva-microsweeper-waf"
    
    az network front-door waf-policy create \
        --name "$WAF_POLICY_NAME" \
        --resource-group "$AZ_RG" \
        --mode Detection \
        --sku Standard_AzureFrontDoor
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create WAF policy"
        return 1
    fi
    
    echo "✅ WAF policy '$WAF_POLICY_NAME' created"
    
    # Enable OWASP rule set
    az network front-door waf-policy managed-rules add \
        --policy-name "$WAF_POLICY_NAME" \
        --resource-group "$AZ_RG" \
        --type DefaultRuleSet \
        --version 1.1
    
    echo "✅ OWASP rule set enabled"
    
    # Associate WAF policy with Front Door (requires custom domain)
    if [ -n "$APP_DOMAIN" ]; then
        az afd security-policy create \
            --security-policy-name "microsweeper-security-policy" \
            --profile-name "$FRONTDOOR_NAME" \
            --resource-group "$AZ_RG" \
            --domains "microsweeper-custom-domain" \
            --waf-policy "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$AZ_RG/providers/Microsoft.Network/frontdoorWebApplicationFirewallPolicies/$WAF_POLICY_NAME"
        
        echo "✅ WAF policy associated with custom domain"
    else
        echo "ℹ️  WAF policy created but not associated (custom domain required)"
    fi
}

# Configure WAF (uncomment to enable)
# configure_waf
```

### Step 10: Verification and Testing

```bash
# Complete verification and testing
verify_deployment() {
    echo "🧪 Running deployment verification..."
    
    echo "1. Checking Azure Front Door profile..."
    az afd profile show \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query "{name: name, state: provisioningState, sku: sku.name}" \
        --output table
    
    echo "2. Checking Front Door endpoint..."
    az afd endpoint show \
        --endpoint-name "$ENDPOINT_NAME" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query "{name: name, hostname: hostName, state: provisioningState}" \
        --output table
    
    echo "3. Checking origin health..."
    az afd origin show \
        --origin-name "aro-microsweeper-origin" \
        --origin-group-name "$ORIGIN_GROUP" \
        --profile-name "$FRONTDOOR_NAME" \
        --resource-group "$AZ_RG" \
        --query "{name: name, hostname: hostName, enabled: enabled}" \
        --output table
    
    echo "4. Testing default endpoint..."
    echo "🌐 Default Front Door endpoint: https://$DEFAULT_ENDPOINT_HOST"
    curl -I https://$DEFAULT_ENDPOINT_HOST --connect-timeout 15 --max-time 30
    
    echo ""
    echo "5. Checking OpenShift routes..."
    oc get routes -n $NAMESPACE
    
    echo ""
    echo "=================================================="
    echo "DEPLOYMENT SUMMARY"
    echo "=================================================="
    echo "✅ Azure Front Door Profile: $FRONTDOOR_NAME"
    echo "✅ Front Door Endpoint: $ENDPOINT_NAME"
    echo "✅ Default Domain: https://$DEFAULT_ENDPOINT_HOST"
    echo "✅ Origin: $PUBLIC_ROUTE_HOST"
    echo "✅ OpenShift Namespace: $NAMESPACE"
    
    if [ -n "$APP_DOMAIN" ]; then
        echo "🌍 Custom Domain: https://$APP_DOMAIN (requires DNS configuration)"
    fi
    
    echo "=================================================="
}

# Run verification
verify_deployment
```

### Complete Deployment Script

```bash
#!/bin/bash
# Complete deployment script for Azure Front Door with ARO

# Set environment variables
export AZ_USER="rooliva@microsoft.com"
export AZ_RG="arogbbwestus3"
export AZ_ARO="aroclustergbb"
export AZ_LOCATION="westus3"
export CUSTOM_DOMAIN="${AZ_USER}.apps.arolatamgbb.jaropro.net"
export APP_DOMAIN="rooliva00.apps.arolatamgbb.jaropro.net"
export FRONTDOOR_NAME="rooliva-microsoft-com-fd"
export ENDPOINT_NAME="rooliva-endpoint"
export ORIGIN_GROUP="rooliva-origins"
export NAMESPACE="microsweeper-ex"
export APP_SERVICE="microsweeper-appservices"

echo "🚀 Starting Azure Front Door deployment for ARO..."

# Run all deployment steps
validate_and_login && \
get_app_route_info && \
create_frontdoor_profile && \
configure_origin && \
create_default_route && \
configure_openshift_route && \
verify_deployment

echo "🎉 Deployment completed!"
echo ""
echo "Next steps (optional):"
echo "1. Configure custom domain DNS records"
echo "2. Run: validate_and_create_custom_route"
echo "3. Enable WAF: configure_waf"
```

### Troubleshooting This Specific Deployment

```bash
# Troubleshooting commands specific to this deployment
troubleshoot_deployment() {
    echo "🔍 Troubleshooting deployment..."
    
    # Check if service name is correct
    echo "1. Checking application service..."
    oc get services -n $NAMESPACE | grep -E "(microsweeper|${APP_SERVICE})"
    
    # Check if there are multiple services with similar names
    if [ $? -ne 0 ]; then
        echo "Service '$APP_SERVICE' not found. Available services:"
        oc get services -n $NAMESPACE
        echo ""
        echo "💡 Suggestion: Update APP_SERVICE variable with the correct service name"
    fi
    
    # Check ARO cluster connectivity
    echo "2. Testing ARO cluster connectivity..."
    oc cluster-info
    
    # Check Front Door provisioning state
    echo "3. Checking Front Door provisioning..."
    az afd profile show --profile-name "$FRONTDOOR_NAME" --resource-group "$AZ_RG" --query provisioningState -o tsv
    
    # Test origin connectivity from Azure
    echo "4. Testing origin accessibility..."
    if [ -n "$PUBLIC_ROUTE_HOST" ]; then
        echo "Testing: https://$PUBLIC_ROUTE_HOST"
        curl -I https://$PUBLIC_ROUTE_HOST --connect-timeout 10
    fi
}

# Run troubleshooting
# troubleshoot_deployment
```

This practical implementation section provides:

1. **Real Environment Configuration** - Using the specific values you provided
2. **Complete Step-by-Step Process** - From validation to final testing
3. **Error Handling** - Proper checks and error messages
4. **Modular Functions** - Each step as a separate function for easy debugging
5. **Verification Steps** - Comprehensive testing and validation
6. **Troubleshooting** - Specific to this deployment scenario
7. **Complete Script** - Ready-to-run automation

The implementation handles the specific service name variation (`microsweeper-appservices` vs `microsweeper-appservice`) and provides proper domain configuration for the `arolatamgbb.jaropro.net` domain structure.

## Additional Resources

- [Azure Front Door Documentation](https://learn.microsoft.com/en-us/azure/frontdoor/)
- [ARO Documentation](https://learn.microsoft.com/en-us/azure/openshift/)
- [OpenShift Networking Documentation](https://docs.openshift.com/container-platform/latest/networking/understanding-networking.html)
- [Azure WAF Documentation](https://learn.microsoft.com/en-us/azure/web-application-firewall/)
- [Private Link Service Documentation](https://learn.microsoft.com/en-us/azure/private-link/private-link-service-overview) Cannot reach API server - check network connectivity"
        fi
    fi
    
    # Check if oc CLI is installed and working
    echo "5. Verifying OpenShift CLI..."
    oc version --client
    if [ $? -ne 0 ]; then
        echo "❌ OpenShift CLI not installed or not working"
        echo "   Install with: curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz"
    fi
}

# Run troubleshooting if needed
# troubleshoot_openshift_login
```

### How to Obtain Required Values

#### Getting ARO Cluster Information

To get information about your ARO cluster:

```bash
# Get ARO console URL
export OCP_CONSOLE="$(az aro show --name ${AZ_ARO} \
  --resource-group ${AZ_RG} \
  -o tsv --query consoleProfile)"

# Get ARO API server URL
export OCP_API="$(az aro show --name ${AZ_ARO} \
  --resource-group ${AZ_RG} \
  --query apiserverProfile.url -o tsv)"

# Verify the variables
echo "Console URL: ${OCP_CONSOLE}"
echo "API Server: ${OCP_API}"
```

#### Getting Application Route Information

After deploying your application:

```bash
# Get the public route hostname for your application
export PUBLIC_ROUTE_HOST=$(oc -n ${NAMESPACE} get route ${APP_SERVICE} -o jsonpath='{.spec.host}')
echo "Public Route: ${PUBLIC_ROUTE_HOST}"

# For private clusters, get the private ingress controller service
export PRIVATE_LB_IP=$(oc -n openshift-ingress get service router-private -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Private Load Balancer IP: ${PRIVATE_LB_IP}"
```

#### Getting Front Door Endpoint Information

After creating your Front Door endpoint:

```bash
# Get the Front Door endpoint hostname
export FRONTDOOR_ENDPOINT=$(az afd endpoint show \
  --endpoint-name ${ENDPOINT_NAME} \
  --profile-name ${FRONTDOOR_NAME} \
  --resource-group ${AZ_RG} \
  --query hostName -o tsv)
echo "Front Door Endpoint: ${FRONTDOOR_ENDPOINT}"
```

These variables will be essential when configuring Azure Front Door and connecting it to your ARO cluster. Make sure to set them before proceeding with the implementation steps.

## Implementation Steps

### 1. Deploy Your Application

If you haven't already deployed an application, follow the steps in the workshop to deploy the microsweeper app:

```bash
# Create a namespace for your application
oc new-project microsweeper-ex

# Clone the application repository
git clone https://github.com/rh-mobb/aro-workshop-app.git
cd aro-workshop-app

# Add the OpenShift extension to Quarkus CLI
quarkus ext add openshift

# Add Kubernetes config extension
quarkus ext add kubernetes-config

# Create database credentials secret
cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: microsweeper-secret
  namespace: microsweeper-ex
type: Opaque
stringData:
  PG_URL: jdbc:postgresql://<your-db-host>:5432/postgres
  PG_USER: <your-db-user>
  PG_PASS: <your-db-password>
EOF

# Configure application properties
cat <<"EOF" > ./src/main/resources/application.properties
# Database configurations
%prod.quarkus.datasource.db-kind=postgresql
%prod.quarkus.datasource.jdbc.url=${PG_URL}
%prod.quarkus.datasource.username=${PG_USER}
%prod.quarkus.datasource.password=${PG_PASS}
%prod.quarkus.datasource.jdbc.driver=org.postgresql.Driver
%prod.quarkus.hibernate-orm.database.generation=update

# OpenShift configurations
%prod.quarkus.kubernetes-client.trust-certs=true
%prod.quarkus.kubernetes.deploy=true
%prod.quarkus.kubernetes.deployment-target=openshift
%prod.quarkus.openshift.build-strategy=docker
%prod.quarkus.openshift.expose=true
%prod.quarkus.openshift.deployment-kind=Deployment
%prod.quarkus.container-image.group=microsweeper-ex
%prod.quarkus.openshift.env.secrets=microsweeper-secret
EOF

# Build and deploy the application
quarkus build --no-tests

# Configure Prometheus monitoring (optional)
cat << EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: microsweeper-monitor
  name: microsweeper-monitor
  namespace: microsweeper-ex
spec:
  endpoints:
  - interval: 30s
    targetPort: 8080
    path: /q/metrics
    scheme: http
  selector:
    matchLabels:
      app.kubernetes.io/name: microsweeper-appservice
EOF
```

### 2. Configure a Private Ingress Controller (Required for Private Clusters)

For private clusters, you need to configure a private ingress controller:

```bash
# Create a private ingress controller configuration
cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: private
  namespace: openshift-ingress-operator
spec:
  domain: private.${DOMAIN}
  endpointPublishingStrategy:
    loadBalancerStrategy:
      scope: Internal
    type: LoadBalancerService
  routeSelector:
    matchLabels:
      type: private
EOF
```

Verify the private ingress controller is available:

```bash
oc get IngressController private -n openshift-ingress-operator -o jsonpath='{.status.conditions}' | jq
```

### 3. Detailed Azure Front Door Configuration

This section provides detailed instructions for creating and configuring Azure Front Door for integration with ARO.

#### Step 1: Environment Preparation

Before starting, we need to set up the necessary environment variables:

```bash
# Basic variables
export AZ_USER="user1"                    # Your assigned username
export AZ_RG="${AZ_USER}-rg"             # Resource group name
export AZ_ARO="${AZ_USER}-cluster"       # ARO cluster name
export AZ_LOCATION="eastus"              # Azure region
export UNIQUE="$(openssl rand -hex 4)"   # Unique identifier

# Front Door variables
export FRONTDOOR_NAME="${AZ_USER}-frontdoor"     # Front Door profile name
export ENDPOINT_NAME="${AZ_USER}-endpoint"       # Front Door endpoint name
export ORIGIN_GROUP="${AZ_USER}-origins"         # Origin group name
export APP_DOMAIN="app.${AZ_USER}.example.com"   # Custom domain for application
```

#### Step 2: Creating Azure Front Door Profile

The Front Door profile is the main resource that contains all the configuration:

```bash
# Create Front Door profile (Standard tier recommended for WAF capabilities)
az afd profile create \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --sku Standard_AzureFrontDoor

# Verify profile creation
az afd profile show \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --output table
```

**Detailed explanation:**
- **--profile-name**: Defines the unique name for your Front Door profile.
- **--resource-group**: The resource group where the profile will be created.
- **--sku**: Service tier. Standard allows WAF usage, while Premium offers additional security features.

#### Step 3: Creating Front Door Endpoint

Endpoints are the entry points for traffic:

```bash
# Create endpoint
az afd endpoint create \
  --endpoint-name $ENDPOINT_NAME \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --enabled true

# Get the default endpoint hostname (for testing)
DEFAULT_ENDPOINT_HOST=$(az afd endpoint show \
  --endpoint-name $ENDPOINT_NAME \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --query hostName -o tsv)
echo "Default endpoint host: ${DEFAULT_ENDPOINT_HOST}"
```

**Detailed explanation:**
- **--endpoint-name**: Unique name for your endpoint.
- **--enabled**: Activates the endpoint immediately after creation.
- The command generates a default hostname with format `{endpoint-name}.z01.azurefd.net`.

#### Step 4: Origin Group Configuration

The origin group defines how multiple origins are aggregated and load balanced:

```bash
# Create origin group with health probe configuration
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

# Verify origin group creation
az afd origin-group show \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --output table
```

**Detailed explanation:**
- **--probe-request-type**: Type of HTTP request for health checking.
- **--probe-path**: URL path used for health probing.
- **--probe-interval-in-seconds**: Frequency of health probes.
- **--sample-size**: Number of samples to evaluate origin health.
- **--successful-samples-required**: Number of successful samples needed to consider origin healthy.
- **--additional-latency-in-milliseconds**: Additional latency tolerated before considering an origin degraded.

#### Step 5: Origin Configuration

The origin defines where your application is located:

##### For Public ARO Clusters:

```bash
# Get the public route hostname for the application
PUBLIC_ROUTE_HOST=$(oc -n microsweeper-ex get route microsweeper-appservice -o jsonpath='{.spec.host}')
echo "Public route host: $PUBLIC_ROUTE_HOST"

# Create origin pointing to the public route
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
  --enabled true

# Verify origin creation
az afd origin show \
  --origin-name "aro-app-origin" \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --output table
```

##### For Private ARO Clusters:

```bash
# Get the Private Link Service ID created by the private ingress controller
PRIVATE_LINK_SERVICE_ID=$(az network private-link-service list \
  --resource-group $AZ_RG \
  --query "[?contains(name, 'private')].id" -o tsv)
echo "Private Link Service ID: $PRIVATE_LINK_SERVICE_ID"

# Create origin with private link
az afd origin create \
  --origin-name "aro-private-origin" \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --enabled true \
  --origin-host-header $APP_DOMAIN \
  --private-link-resource-id $PRIVATE_LINK_SERVICE_ID \
  --private-link-location $AZ_LOCATION \
  --private-link-request-message "Request access to private ingress"
```

**Detailed explanation:**
- **--host-name**: Origin server hostname (public or private route).
- **--origin-host-header**: Host header sent to the origin (important for correct routing).
- **--http-port/--https-port**: Ports used for communication with the origin.
- **--priority**: Origin priority (relevant when there are multiple origins).
- **--weight**: Weight for load balancing (relevant when there are multiple origins).
- **--private-link-resource-id**: Private Link Service resource ID (private clusters only).
- **--private-link-location**: Private Link location (must match cluster region).

#### Step 6: Route Creation

The route defines how requests are routed from the endpoint to the origin:

```bash
# Create a route with the default endpoint domain
az afd route create \
  --route-name app-route \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --endpoint-name $ENDPOINT_NAME \
  --origin-group $ORIGIN_GROUP \
  --https-redirect enabled \
  --forwarding-protocol HttpsOnly \
  --supported-protocols Http Https \
  --link-to-default-domain true \
  --patterns "/*"

# Verify route creation
az afd route show \
  --route-name app-route \
  --profile-name $FRONTDOOR_NAME \
  --endpoint-name $ENDPOINT_NAME \
  --resource-group $AZ_RG \
  --output json | jq .
```

**Detailed explanation:**
- **--https-redirect**: Automatically redirects HTTP traffic to HTTPS.
- **--forwarding-protocol**: Protocol used to send requests to the origin.
- **--supported-protocols**: Protocols accepted at the endpoint.
- **--link-to-default-domain**: Links the route to the endpoint's default domain.
- **--patterns**: URL patterns that will match this route (/* matches all routes).

### 4. Domain Configuration - Automatic vs Custom

Azure Front Door offers two options for domains: the default domain automatically provided by Azure and custom domains.

#### Option A: Automatic Domain Provided by Azure

When you create an endpoint in Azure Front Door, you automatically get a domain with the format `{endpoint-name}.z01.azurefd.net`. This domain:

- **Is generated automatically** when creating the endpoint
- **Includes SSL/TLS certificate** managed by Azure
- **Requires no additional DNS configuration**
- **Is perfect for testing** and development

```bash
# The automatic domain is already available after creating the endpoint
echo "Your automatic domain is: ${DEFAULT_ENDPOINT_HOST}"

# Create route using only the automatic domain
az afd route create \
  --route-name app-route-auto \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --endpoint-name $ENDPOINT_NAME \
  --origin-group $ORIGIN_GROUP \
  --https-redirect enabled \
  --forwarding-protocol HttpsOnly \
  --supported-protocols Http Https \
  --link-to-default-domain true \
  --patterns "/*"

# Verify it works immediately
echo "You can access your application at: https://${DEFAULT_ENDPOINT_HOST}"
curl -Ik https://$DEFAULT_ENDPOINT_HOST
```

**Advantages of automatic domain:**
- ✅ Immediate configuration
- ✅ SSL certificate included
- ✅ No DNS management required
- ✅ Perfect for development and testing

**Disadvantages of automatic domain:**
- ❌ User-unfriendly name
- ❌ Doesn't reflect your brand or company
- ❌ Azure-dependent (not portable)

#### Option B: Custom Domain

For production, you'll probably want to use your own domain. This process requires more steps but offers greater control:

##### Step 1: Create custom domain in Azure Front Door

```bash
# Define your custom domain
export APP_DOMAIN="app.mycompany.com"  # Replace with your actual domain

# Create custom domain
az afd custom-domain create \
  --custom-domain-name "my-app-domain" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --host-name $APP_DOMAIN \
  --minimum-tls-version "TLS12" \
  --certificate-type ManagedCertificate

# Verify custom domain status
az afd custom-domain show \
  --custom-domain-name "my-app-domain" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --output table
```

##### Step 2: Domain ownership validation

Azure requires you to prove you own the domain:

```bash
# Get the validation token
VALIDATION_TOKEN=$(az afd custom-domain show \
  --custom-domain-name "my-app-domain" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --query "validationProperties.validationToken" -o tsv)

echo "=================================================="
echo "REQUIRED DNS CONFIGURATION FOR VALIDATION"
echo "=================================================="
echo "Record type: TXT"
echo "Name: _dnsauth.${APP_DOMAIN}"
echo "Value: ${VALIDATION_TOKEN}"
echo "TTL: 3600 (recommended)"
echo "=================================================="
echo ""
echo "⚠️  IMPORTANT: You must create this TXT record in your DNS provider"
echo "   before continuing with the next steps."
```

##### Step 3: DNS configuration for traffic routing

Besides the TXT record for validation, you need a CNAME record:

```bash
echo "=================================================="
echo "DNS CONFIGURATION FOR TRAFFIC ROUTING"
echo "=================================================="
echo "Record type: CNAME"
echo "Name: app (or your preferred subdomain)"
echo "Value: ${DEFAULT_ENDPOINT_HOST}"
echo "TTL: 3600 (recommended)"
echo "=================================================="
echo ""
echo "Final result: app.mycompany.com -> ${DEFAULT_ENDPOINT_HOST}"
```

##### Step 4: Verify domain validation

```bash
# Function to verify domain validation
check_domain_validation() {
    local status=$(az afd custom-domain show \
        --custom-domain-name "my-app-domain" \
        --profile-name $FRONTDOOR_NAME \
        --resource-group $AZ_RG \
        --query "domainValidationState" -o tsv 2>/dev/null)
    
    echo "Domain validation status: $status"
    
    case $status in
        "Approved")
            echo "✅ Domain validated successfully"
            return 0
            ;;
        "Pending")
            echo "⏳ Validation pending. Verify TXT record is configured."
            return 1
            ;;
        "Rejected")
            echo "❌