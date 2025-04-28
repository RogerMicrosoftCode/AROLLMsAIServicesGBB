#/bin/bash
az login --use-device-code --tenant 16b3c013-d300-468d-ac64-7eda0820b6d3
export LOCATION="westus3"
export RESOURCEGROUP="arogbbwestus3"
export CLUSTER="aroclusterwestus3"
export SP_CLIENT_ID="service-principal-client-id"
export SP_CLIENT_SECRET="service-principal-client-secret"
az group create --name $RESOURCEGROUP --location $LOCATION
az network vnet create --resource-group $RESOURCEGROUP --name aro-vnet --address-prefixes 192.168.192.0/23
az network vnet subnet create --resource-group $RESOURCEGROUP --vnet-name aro-vnet --name master-subnet --address-prefixes 192.168.192.0/25 --service-endpoints Microsoft.ContainerRegistry
az network vnet subnet create --resource-group $RESOURCEGROUP --vnet-name aro-vnet --name worker-subnet --address-prefixes 192.168.192.128/25 --service-endpoints Microsoft.ContainerRegistry
az network vnet subnet update --name master-subnet --resource-group $RESOURCEGROUP --vnet-name aro-vnet --disable-private-link-service-network-policies true
az aro create --resource-group $RESOURCEGROUP --name arolatamgbb --vnet aro-vnet --master-subnet master-subnet --worker-subnet worker-subnet --apiserver-visibility Private --ingress-visibility Private --domain arolatamgbb.jaropro.net --pull-secret @pull-secret.txt
az aro create --resource-group $RESOURCEGROUP --name arolatamgbb --vnet aro-vnet --master-subnet master-subnet --worker-subnet worker-subnet --apiserver-visibility Private --ingress-visibility Private --domain arolatamgbb.jaropro.net --pull-secret @pull-secret.txt --client-id $SP_CLIENT_ID --client-secret $SP_CLIENT_SECRET
