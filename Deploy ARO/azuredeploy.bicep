@description('Location')
param location string = 'eastus'

@description('Domain Prefix')
param domain string = ''

@description('Pull secret from cloud.redhat.com. The json should be input as a string')
param pullSecret string

@description('Name of ARO vNet')
param clusterVnetName string = 'aro-vnet'

@description('ARO vNet Address Space')
param clusterVnetCidr string = '10.100.0.0/15'

@description('Worker node subnet address space')
param workerSubnetCidr string = '10.100.70.0/23'

@description('Master node subnet address space')
param masterSubnetCidr string = '10.100.76.0/24'

@description('Master Node VM Type')
param masterVmSize string = 'Standard_D8s_v3'

@description('Worker Node VM Type')
param workerVmSize string = 'Standard_D4s_v3'

@description('Worker Node Disk Size in GB')
@minValue(128)
param workerVmDiskSize int = 128

@description('Number of Worker Nodes')
@minValue(3)
param workerCount int = 3

@description('Cidr for Pods')
param podCidr string = '10.128.0.0/14'

@metadata({
  description: 'Cidr of service'
})
param serviceCidr string = '172.30.0.0/16'

@description('Unique name for the cluster')
param clusterName string

@description('Tags for resources')
param tags object = {
  env: 'Dev'
  dept: 'Ops'
}

@description('Api Server Visibility')
@allowed([
  'Private'
  'Public'
])
param apiServerVisibility string = 'Public'

@description('Ingress Visibility')
@allowed([
  'Private'
  'Public'
])
param ingressVisibility string = 'Public'

@description('The Application ID of an Azure Active Directory client application')
param aadClientId string

@description('The Object ID of an Azure Active Directory client application')
param aadObjectId string

@description('The secret of an Azure Active Directory client application')
@secure()
param aadClientSecret string

@description('The ObjectID of the Resource Provider Service Principal')
param rpObjectId string

@description('Specify if FIPS validated crypto modules are used')
@allowed([
  'Enabled'
  'Disabled'
])
param fips string = 'Disabled'

@description('Specify if master VMs are encrypted at host')
@allowed([
  'Enabled'
  'Disabled'
])
param masterEncryptionAtHost string = 'Disabled'

@description('Specify if worker VMs are encrypted at host')
@allowed([
  'Enabled'
  'Disabled'
])
param workerEncryptionAtHost string = 'Disabled'

var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var resourceGroupId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/aro-${domain}-${location}'
var masterSubnetId=resourceId('Microsoft.Network/virtualNetworks/subnets', clusterVnetName, 'master')
var workerSubnetId=resourceId('Microsoft.Network/virtualNetworks/subnets', clusterVnetName, 'worker')

resource clusterVnetName_resource 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: clusterVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        clusterVnetCidr
      ]
    }
    subnets: [
      {
        name: 'master'
        properties: {
          addressPrefix: masterSubnetCidr
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'worker'
        properties: {
          addressPrefix: workerSubnetCidr
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
        }
      }
    ]
  }
}

resource clusterVnetName_Microsoft_Authorization_id_name_aadObjectId 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(aadObjectId, clusterVnetName_resource.id, contributorRoleDefinitionId)
  scope: clusterVnetName_resource
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: aadObjectId
    principalType: 'ServicePrincipal'
  }
}

resource clusterVnetName_Microsoft_Authorization_id_name_rpObjectId 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(rpObjectId, clusterVnetName_resource.id, contributorRoleDefinitionId)
  scope: clusterVnetName_resource
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: rpObjectId
    principalType: 'ServicePrincipal'
  }
}

resource clusterName_resource 'Microsoft.RedHatOpenShift/OpenShiftClusters@2023-04-01' = {
  name: clusterName
  location: location
  tags: tags
  properties: {
    clusterProfile: {
      domain: domain
      resourceGroupId: resourceGroupId
      pullSecret: pullSecret
      fipsValidatedModules: fips
    }
    networkProfile: {
      podCidr: podCidr
      serviceCidr: serviceCidr
    }
    servicePrincipalProfile: {
      clientId: aadClientId
      clientSecret: aadClientSecret
    }
    masterProfile: {
      vmSize: masterVmSize
      subnetId: masterSubnetId
      encryptionAtHost: masterEncryptionAtHost
    }
    workerProfiles: [
      {
        name: 'worker'
        vmSize: workerVmSize
        diskSizeGB: workerVmDiskSize
        subnetId: workerSubnetId
        count: workerCount
        encryptionAtHost: workerEncryptionAtHost
      }
    ]
    apiserverProfile: {
      visibility: apiServerVisibility
    }
    ingressProfiles: [
      {
        name: 'default'
        visibility: ingressVisibility
      }
    ]
  }
  dependsOn: [
    clusterVnetName_resource
  ]
}
