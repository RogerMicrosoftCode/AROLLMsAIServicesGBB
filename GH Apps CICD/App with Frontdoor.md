# Azure Front Door Integration with Azure Red Hat OpenShift (ARO)

This guide demonstrates how to expose applications running on an Azure Red Hat OpenShift (ARO) cluster using Azure Front Door. We'll cover both public and private cluster scenarios with detailed step-by-step instructions.

## Environment Variables Setup

Before starting with Azure Front Door deployment, we need to set up the necessary environment variables. These variables will be used throughout the implementation process.

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

### 3. Set Up Azure Front Door

#### Create an Azure Front Door Profile

```bash
# Set variables
FRONTDOOR_NAME="${AZ_USER}-frontdoor"
ENDPOINT_NAME="${AZ_USER}-endpoint"
ORIGIN_GROUP="${AZ_USER}-origins"
APP_DOMAIN="app.${AZ_USER}.example.com"  # Your custom domain

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
  --enabled true
```

#### Configure Origin Group and Origin

##### For Public Clusters:

```bash
# Get your app's route hostname if not already set
if [ -z "$PUBLIC_ROUTE_HOST" ]; then
  PUBLIC_ROUTE_HOST=$(oc -n $NAMESPACE get route $APP_SERVICE -o jsonpath='{.spec.host}')
  echo "Public Route Host: $PUBLIC_ROUTE_HOST"
fi

# Create origin group with health probe settings
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

##### For Private Clusters:

```bash
# First, get the Private Link Service ID created by the private ingress controller
# This assumes you've created a private ingress controller as shown earlier
PRIVATE_LINK_SERVICE_ID=$(az network private-link-service list \
  --resource-group $AZ_RG \
  --query "[?contains(name, 'private')].id" -o tsv)
echo "Private Link Service ID: $PRIVATE_LINK_SERVICE_ID"

# Create origin group
az afd origin-group create \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --probe-request-type GET \
  --probe-protocol Http \
  --probe-path "/" \
  --probe-interval-in-seconds 60

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

#### Create Route and Custom Domain

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
```

##### Important DNS Configuration:

After creating the custom domain in Front Door, you need to:

1. Add a TXT record for domain validation:
   * Name: `_dnsauth.app.yourdomain.com`
   * Value: The validation token from the command above
   * TTL: 3600

2. Add a CNAME record to point your domain to Front Door:
   * Name: `app.yourdomain.com`
   * Value: Your Front Door endpoint (`{endpoint-name}.z01.azurefd.net`)
   * TTL: 3600

### 4. Configure Route in OpenShift

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

### 5. Configure DNS

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

## Advanced Configuration

- Enable the Web Application Firewall (WAF) on Front Door
- Configure session affinity for stateful applications
- Set up geo-filtering to restrict access from specific countries
- Implement custom routing rules based on URL paths

## Conclusion

Integrating Azure Front Door with your ARO cluster provides a secure, high-performance way to expose your applications globally while maintaining control over your infrastructure. Whether using a public or private cluster, Front Door offers significant benefits for production workloads.

---

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
  --domains app-domain \
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

## Additional Resources

- [Azure Front Door Documentation](https://learn.microsoft.com/en-us/azure/frontdoor/)
- [ARO Documentation](https://learn.microsoft.com/en-us/azure/openshift/)
- [OpenShift Networking Documentation](https://docs.openshift.com/container-platform/latest/networking/understanding-networking.html)
- [Azure WAF Documentation](https://learn.microsoft.com/en-us/azure/web-application-firewall/)
- [Private Link Service Documentation](https://learn.microsoft.com/en-us/azure/private-link/private-link-service-overview)