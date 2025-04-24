I'll add this optional deployment method to the 3install.md file:

# Cluster Installation

At this point, you are ready to perform the OpenShift installation. See below for an example of an installation.

# Create an ARO Cluster

During this workshop, you will be working on a cluster that you will create yourself in this step. This cluster will be dedicated to you. Each person has been assigned a workshop user ID, if you need a user ID please see a facilitator.

The first step we need to do is assign an environment variable to this user ID. All the Azure resources that you will be creating will be placed in a resource group that matches this user ID. The user ID will be in the following format: userX. For example user1.

While in the Azure Cloud Shell that you should still have open from the "Environment Setup" section, run the following command to ensure the system has the correct environment variables for your user (If not, request help):

```bash
env | grep -E 'AZ_'
```

## Get a Red Hat pull secret

The next step is to get a Red Hat pull secret for your ARO cluster. This pull secret will give you permissions to deploy ARO and access to Red Hat's Operator Hub among things.

1. Login to [https://console.redhat.com/openshift/downloads#tool-pull-secret](https://console.redhat.com/openshift/downloads#tool-pull-secret). If you don't have an account yet, it is good a time to create it. ;)

2. hit the `Download` button. This will download the file in your laptop.

3. In the cloudshell, upload the pull-secret file.

## Networking

Before we can create an ARO cluster, we need to setup the virtual network that the cluster will use. 

0. Resource group and VNET creation

    ```bash
    
    AZR_ARO_VNET_PREFIXES=10.0.0.0/21
    
    AZR_ARO_SUBNET_MASTER_PREFIXES=10.0.0.0/23
    
    AZR_ARO_SUBNET_WORKER_PREFIXES=10.0.2.0/23
    
    echo "----> Create virtual network"
    az network vnet create \
      --address-prefixes $AZR_ARO_VNET_PREFIXES \
      --name "${AZ_USER}-vnet" \
      --resource-group $AZ_RG
    echo "----> Create control plane subnet"
    az network vnet subnet create \
      --resource-group $AZ_RG \
      --vnet-name "${AZ_USER}-vnet" \
      --name "${AZ_USER}-cp-subnet" \
      --address-prefixes $AZR_ARO_SUBNET_MASTER_PREFIXES \
      --service-endpoints Microsoft.ContainerRegistry
    echo "----> Create machine subnet subnet"
    az network vnet subnet create \
      --resource-group $AZ_RG \
      --vnet-name "${AZ_USER}-vnet" \
      --name "${AZ_USER}-machine-subnet" \
      --address-prefixes $AZR_ARO_SUBNET_WORKER_PREFIXES \
      --service-endpoints Microsoft.ContainerRegistry
    echo "----> Update control plane subnet to disable private link service network policies"
    az network vnet subnet update \
      --name "${AZ_USER}-cp-subnet" \
      --resource-group $AZ_RG \
      --vnet-name "${AZ_USER}-vnet" \
      --disable-private-link-service-network-policies true
    ```

1. Verify virtual network (vNet)

    ```bash
    az network vnet show \
      --name "${AZ_USER}-vnet" \
      --resource-group "${AZ_RG}" | jq .name
    ```

2. Verify control plane subnet

    ```bash
    az network vnet subnet show \
      --resource-group "${AZ_RG}" \
      --vnet-name "${AZ_USER}-vnet" \
      --name "${AZ_USER}-cp-subnet" | jq .name
    ```

3. Verify machine subnet

    ```bash
    az network vnet subnet show \
      --resource-group "${AZ_RG}" \
      --vnet-name "${AZ_USER}-vnet" \
      --name "${AZ_USER}-machine-subnet" | jq .name
    ```

## Cluster Creation

You have two options for cluster creation:

### Option 1: Using the Azure CLI (Standard Method)

This method uses the Azure CLI to create an ARO cluster directly:

```bash
az aro create \
  --resource-group "${AZ_RG}" \
  --name "${AZ_ARO}" \
  --vnet "${AZ_USER}-vnet" \
  --master-subnet "${AZ_USER}-cp-subnet" \
  --worker-subnet "${AZ_USER}-machine-subnet" \
  --pull-secret @~/pull-secret
```

> This will take between 30 and 45 minutes.

### Option 2: Using Templates Command (Optional)

Alternatively, you can deploy an ARO cluster using Azure Bicep templates with the following command:

```bash
az deployment group create \
  --name aroDeployment \
  --resource-group $RESOURCEGROUP \
  --template-file azuredeploy.bicep \
  --parameters location=$LOCATION \
  --parameters domain=$DOMAIN \
  --parameters pullSecret=$PULL_SECRET \
  --parameters clusterName=$ARO_CLUSTER_NAME \
  --parameters aadClientId=$SP_CLIENT_ID \
  --parameters aadObjectId=$SP_OBJECT_ID \
  --parameters aadClientSecret=$SP_CLIENT_SECRET \
  --parameters rpObjectId=$ARO_RP_SP_OBJECT_ID
```

This method requires you to have the following parameters defined:
- `$RESOURCEGROUP`: Your target resource group
- `$LOCATION`: Azure region (e.g., eastus)
- `$DOMAIN`: Domain for your cluster
- `$PULL_SECRET`: Your Red Hat pull secret
- `$ARO_CLUSTER_NAME`: Name for your ARO cluster
- `$SP_CLIENT_ID`: Service Principal's client ID
- `$SP_OBJECT_ID`: Service Principal's object ID
- `$SP_CLIENT_SECRET`: Service Principal's client secret
- `$ARO_RP_SP_OBJECT_ID`: ARO Resource Provider Service Principal object ID

This deployment method gives you more control over the detailed parameters of your ARO deployment.

---

While the cluster is being created, let's learn more about what you will be doing in this workshop.

Details Command AZ ARO CREATE FLAGS
az aro create --master-subnet
              --name
              --resource-group
              --worker-subnet
              [--apiserver-visibility {Private, Public}]
              [--client-id]
              [--client-secret]
              [--cluster-resource-group]
              [--disk-encryption-set]
              [--domain]
              [--enable-preconfigured-nsg {false, true}]
              [--fips {false, true}]
              [--ingress-visibility {Private, Public}]
              [--lb-ip-count]
              [--location]
              [--master-enc-host {false, true}]
              [--master-vm-size]
              [--no-wait]
              [--outbound-type]
              [--pod-cidr]
              [--pull-secret]
              [--service-cidr]
              [--tags]
              [--version]
              [--vnet]
              [--vnet-resource-group]
              [--worker-count]
              [--worker-enc-host {false, true}]
              [--worker-vm-disk-size-gb]
              [--worker-vm-size]