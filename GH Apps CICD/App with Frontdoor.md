# Azure Front Door Integration with Azure Red Hat OpenShift (ARO)

This guide demonstrates how to expose applications running on an Azure Red Hat OpenShift (ARO) cluster using Azure Front Door. We'll cover both public and private cluster scenarios with detailed step-by-step instructions.

## Overview

Azure Front Door is a global, scalable entry-point that uses the Microsoft global edge network to create fast, secure, and highly scalable web applications. When integrated with ARO, it provides several benefits:

* **Enhanced Security**: WAF and DDoS protection, certificate management, and SSL offloading
* **Global Edge Access**: Traffic is controlled at Microsoft's edge before entering your Azure environment
* **Private Infrastructure**: Your ARO cluster and Azure resources can remain private even when services are publicly accessible

## Architecture

![ARO + Azure Front Door Diagram](https://raw.githubusercontent.com/Azure/ARO-Landing-Zone-Accelerator/main/docs/images/frontdoor-integration.png)

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

## Implementation Steps

### 1. Deploy Your Application

If you haven't already deployed an application, follow the steps in the workshop to deploy the microsweeper app:

```bash
# Create a namespace for your application
oc new-project microsweeper-ex

# Create secrets, deploy the app, etc.
# (See the microsweeper deployment steps in the workshop)
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

For public clusters:

```bash
# Get your app's route hostname
PUBLIC_ROUTE_HOST=$(oc -n microsweeper-ex get route microsweeper-appservice -o jsonpath='{.spec.host}')

# Create origin group
az afd origin-group create \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --probe-request-type GET \
  --probe-protocol Http \
  --probe-path "/" \
  --probe-interval-in-seconds 60

# Create origin pointing to the public route
az afd origin create \
  --origin-name "aro-app-origin" \
  --origin-group-name $ORIGIN_GROUP \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --host-name $PUBLIC_ROUTE_HOST \
  --origin-host-header $PUBLIC_ROUTE_HOST \
  --priority 1 \
  --weight 1000 \
  --enabled true
```

For private clusters, you would connect to the Private Link Service created by the private ingress controller.

#### Create Route and Custom Domain

```bash
# Create a route
az afd route create \
  --route-name app-route \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --endpoint-name $ENDPOINT_NAME \
  --origin-group $ORIGIN_GROUP \
  --https-redirect enabled \
  --forwarding-protocol HttpsOnly \
  --link-to-default-domain true

# Add custom domain (requires DNS validation or cert upload)
az afd custom-domain create \
  --custom-domain-name "app-domain" \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $AZ_RG \
  --host-name $APP_DOMAIN \
  --minimum-tls-version "TLS12" \
  --certificate-type ManagedCertificate
```

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

If your application is not accessible:

1. Verify the ingress controller status
2. Check that your route has the correct hostname
3. Ensure DNS is properly configured with CNAME records
4. Verify Azure Front Door origin health
5. Check for any WAF rules that might be blocking traffic

## Advanced Configuration

- Enable the Web Application Firewall (WAF) on Front Door
- Configure session affinity for stateful applications
- Set up geo-filtering to restrict access from specific countries
- Implement custom routing rules based on URL paths

## Conclusion

Integrating Azure Front Door with your ARO cluster provides a secure, high-performance way to expose your applications globally while maintaining control over your infrastructure. Whether using a public or private cluster, Front Door offers significant benefits for production workloads.

---

## Additional Resources

- [Azure Front Door Documentation](https://docs.microsoft.com/en-us/azure/frontdoor/)
- [ARO Documentation](https://docs.microsoft.com/en-us/azure/openshift/)
- [OpenShift Networking Documentation](https://docs.openshift.com/container-platform/latest/networking/understanding-networking.html)