https://docs.microsoft.com/es-es/azure/storage/files/storage-files-how-to-create-nfs-shares?tabs=azure-portal

# Connect your Azure CLI to your Azure account, if you have not already done so.
az login
# Provide the subscription ID for the subscription where you would like to 
# register the feature
subscriptionId="<yourSubscriptionIDHere>"

ACTIVACION  DE SKU DE AZURE FILE SHARED

export subscriptionId=9a21d481-fa54-4ba9-a90e-520f8d1a5abd
az feature register --name AllowNfsFileShares --namespace Microsoft.Storage --subscription $subscriptionId
az provider register --namespace Microsoft.Storage


TEST DE APROBACION SKU AZURE FILE SHARED

az feature show --name AllowNfsFileShares --namespace Microsoft.Storage --subscription $subscriptionId

CREACION DE STORAGE COMPARTIDO

resourceGroup="<resource-group>"
storageAccount="<storage-account>"
location="westus2"

export resourceGroup=JARODATADBAS
export storageAccount=azurefilenfs
export location=eastus2

az storage account create --resource-group $resourceGroup --name $storageAccount --location $location --sku Premium_LRS --kind FileStorage

CREACION DE SHARED OR FOLDER SHARED
export myshare=azuredatanfs

az storage share-rm create --resource-group $resourceGroup --storage-account $storageAccount --name $myshare --enabled-protocol NFS --root-squash RootSquash --quota 1024