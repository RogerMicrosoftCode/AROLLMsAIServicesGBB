Create the following required identities. Azure Red Hat OpenShift requires nine managed identities, each needs to have an assigned, built-in role:

Seven managed identities related to core OpenShift operators
One managed identity for the Azure Red Hat OpenShift service operator
One additional identity for the cluster to enable the use of these identities
The managed identity components are:

OpenShift Image Registry Operator (image-registry)
OpenShift Network Operator (cloud-network-config)
OpenShift Disk Storage Operator (disk-csi-driver)
OpenShift File Storage Operator (file-csi-driver)
OpenShift Cluster Ingress Operator (ingress)
OpenShift Cloud Controller Manager (cloud-controller-manager)
OpenShift Machine API Operator (machine-api)
Azure Red Hat OpenShift Service Operator (aro-operator)
There are eight different managed identities and corresponding built-in roles that represent the permissions needed for each component of Azure Red Hat OpenShift to perform its duties. In addition, the platform requires one additional identity, the cluster identity, to perform federated credential creation for the previously listed managed identity components (aro-cluster).

az identity create --resource-group $RESOURCEGROUP --name aro-cluster
az identity create --resource-group $RESOURCEGROUP --name cloud-controller-manager
az identity create --resource-group $RESOURCEGROUP --name ingress
az identity create --resource-group $RESOURCEGROUP --name machine-api
az identity create --resource-group $RESOURCEGROUP --name disk-csi-driver 
az identity create --resource-group $RESOURCEGROUP --name cloud-network-config
az identity create --resource-group $RESOURCEGROUP --name image-registry
az identity create --resource-group $RESOURCEGROUP --name file-csi-driver
az identity create --resource-group $RESOURCEGROUP --name aro-operator


Create the required role assignments for each operator identity, cluster identity, and the first party service principal.

SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)

# assign cluster identity permissions over identities previously created

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aro-operator"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cloud-controller-manager"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ingress"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/machine-api"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/disk-csi-driver"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cloud-network-config"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/image-registry"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-cluster --query principalId -o tsv)" \ --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/file-csi-driver"

# assign vnet-level permissions for operators that require it, and subnets-level permission for operators that require it

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name cloud-controller-manager --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/a1f96423-95ce-4224-ab27-4e3dc72facd4" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/master"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name cloud-controller-manager --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/a1f96423-95ce-4224-ab27-4e3dc72facd4" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/worker"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name ingress --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0336e1d3-7a87-462b-b6db-342b63f7802c" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/master"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name ingress --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0336e1d3-7a87-462b-b6db-342b63f7802c" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/worker"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name machine-api --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0358943c-7e01-48ba-8889-02cc51d78637" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/master"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name machine-api --query principalId -o tsv)" \ --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0358943c-7e01-48ba-8889-02cc51d78637" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/worker"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name cloud-network-config --query principalId -o tsv)" \ --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/be7a6435-15ae-4171-8f30-4a343eff9e8f" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name file-csi-driver --query principalId -o tsv)" \ --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0d7aedc0-15fd-4a67-a412-efad370c947e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/master"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name file-csi-driver --query principalId -o tsv)" \ --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0d7aedc0-15fd-4a67-a412-efad370c947e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/worker"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-operator --query principalId -o tsv)" \ --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/4436bae4-7702-4c84-919b-c4069ff25ee2" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/master"

az role assignment create --assignee-object-id "$(az identity show --resource-group $RESOURCEGROUP --name aro-operator --query principalId -o tsv)" \ --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/4436bae4-7702-4c84-919b-c4069ff25ee2" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/worker"

az role assignment create --assignee-object-id "$(az ad sp list --display-name "Azure Red Hat OpenShift RP" --query '[0].id' -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/aro-vnet"

Create the cluster
To create a cluster, run the following command shown under the options. If you choose to use either of the following options, modify the command accordingly:

Option 1: You can pass your Red Hat pull secret, which enables your cluster to access Red Hat container registries along with other content. Add the --pull-secret @pull-secret.txt argument to your command.
Option 2: You can use a custom domain. Add the --domain foo.example.com argument to your command, replacing foo.example.com with your own custom domain.
Create the cluster with the required environment variables. For each --assign-platform-workload-identity flag, the first argument represents the key, which tells the Azure Red Hat OpenShift resource provider which OpenShift operator to use for a given identity. The second argument represents the reference to the identity itself.

az aro create --resource-group $RESOURCEGROUP --name $CLUSTER --vnet aro-vnet --master-subnet master --worker-subnet worker --version <VERSION> --enable-managed-identity --assign-cluster-identity aro-cluster --assign-platform-workload-identity file-csi-driver file-csi-driver --assign-platform-workload-identity cloud-controller-manager cloud-controller-manager --assign-platform-workload-identity ingress ingress --assign-platform-workload-identity image-registry image-registry --assign-platform-workload-identity machine-api machine-api --assign-platform-workload-identity cloud-network-config cloud-network-config --assign-platform-workload-identity aro-operator aro-operator --assign-platform-workload-identity disk-csi-driver disk-csi-driver

As an option, if identity resources exist in a different region or resource group, you can pass full resource IDs to create. See the following example:

az aro create --resource-group $RESOURCEGROUP --name $CLUSTER --vnet aro-vnet --master-subnet master --worker-subnet worker --version <VERSION> --enable-managed-identity --assign-cluster-identity /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aro-cluster --assign-platform-workload-identity file-csi-driver /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/file-csi-driver --assign-platform-workload-identity cloud-controller-manager /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cloud-controller-manager --assign-platform-workload-identity ingress /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ingress --assign-platform-workload-identity image-registry /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/image-registry --assign-platform-workload-identity machine-api /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/machine-api --assign-platform-workload-identity cloud-network-config /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cloud-network-config --assign-platform-workload-identity aro-operator /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aro-operator --assign-platform-workload-identity disk-csi-driver /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCEGROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/disk-csi-driver

Select a different Azure Red Hat OpenShift version
You can choose to use a specific version of Azure Red Hat OpenShift when creating your cluster. First, use the CLI to query for available Azure Red Hat OpenShift versions:

az aro get-versions --location <REGION>