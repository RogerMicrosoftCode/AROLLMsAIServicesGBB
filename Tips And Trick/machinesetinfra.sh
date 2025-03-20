#!/bin/bash

# Generar usuario aleatorio de 5 letras
user=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)

# Obtener nombre de un machineset worker existente para usar como referencia
ORIGINAL_MACHINESET=$(oc -n openshift-machine-api get machine | grep worker | head -1 | awk '{print $1}' | sed 's/-[^-]*$//')
WORKER_MACHINESET=$(oc -n openshift-machine-api get machineset | grep worker | head -1 | awk '{print $1}')

echo "Usando machineset de referencia: ${WORKER_MACHINESET}"

# Obtener información de la infraestructura
INFRASTRUCTURE_ID=$(oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}')
CLUSTER_RESOURCE_GROUP=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.azure.resourceGroupName}')
NETWORK_RESOURCE_GROUP=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.azure.networkResourceGroupName}')

# Obtener información específica del machineset existente
REGION=$(oc get machineset ${WORKER_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.location}')
ZONE=$(oc get machineset ${WORKER_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.zone}')
SKU=$(oc get machineset ${WORKER_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.image.sku}')
VERSION=$(oc get machineset ${WORKER_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.image.version}')
SUBNET=$(oc get machineset ${WORKER_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.subnet}')
VNET=$(oc get machineset ${WORKER_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.vnet}')

# Generar el nombre del nuevo machineset de infraestructura
INFRA_MACHINESET_NAME="${INFRASTRUCTURE_ID}-infra-${REGION}${ZONE}"

echo "Generando plantilla para machineset de infraestructura: ${INFRA_MACHINESET_NAME}"

# Crear el archivo de definición del machineset
cat << EOF > infra-machineset.yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    machine.openshift.io/cluster-api-cluster: ${INFRASTRUCTURE_ID}
    machine.openshift.io/cluster-api-machine-role: infra
    machine.openshift.io/cluster-api-machine-type: infra
  name: ${INFRA_MACHINESET_NAME}
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${INFRASTRUCTURE_ID}
      machine.openshift.io/cluster-api-machineset: ${INFRA_MACHINESET_NAME}
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: ${INFRASTRUCTURE_ID}
        machine.openshift.io/cluster-api-machine-role: infra
        machine.openshift.io/cluster-api-machine-type: infra
        machine.openshift.io/cluster-api-machineset: ${INFRA_MACHINESET_NAME}
    spec:
      metadata:
        creationTimestamp: null
        labels:
          node-role.kubernetes.io/infra: ''
      providerSpec:
        value:
          apiVersion: azureproviderconfig.openshift.io/v1beta1
          credentialsSecret:
            name: azure-cloud-credentials
            namespace: openshift-machine-api
          image:
            offer: aro4
            publisher: azureopenshift
            sku: ${SKU}
            version: ${VERSION}
          kind: AzureMachineProviderSpec
          location: ${REGION}
          metadata:
            creationTimestamp: null
          natRule: null
          networkResourceGroup: ${NETWORK_RESOURCE_GROUP}
          osDisk:
            diskSizeGB: 128
            managedDisk:
              storageAccountType: Premium_LRS
            osType: Linux
          publicIP: false
          resourceGroup: ${CLUSTER_RESOURCE_GROUP}
          tags:
            node_role: infra
          subnet: ${SUBNET}
          userDataSecret:
            name: worker-user-data
          vmSize: Standard_E8s_v5
          vnet: ${VNET}
          zone: ${ZONE}
      taints:
      - key: node-role.kubernetes.io/infra
        effect: NoSchedule
EOF

echo "Archivo de machineset de infraestructura generado en: $(pwd)/infra-machineset.yaml"
echo "Para aplicar el machineset, ejecute: oc apply -f infra-machineset.yaml"

# Mostrar resumen de la configuración
echo ""
echo "Resumen de la configuración:"
echo "============================="
echo "INFRASTRUCTURE_ID: ${INFRASTRUCTURE_ID}"
echo "CLUSTER_RESOURCE_GROUP: ${CLUSTER_RESOURCE_GROUP}"
echo "NETWORK_RESOURCE_GROUP: ${NETWORK_RESOURCE_GROUP}"
echo "REGION: ${REGION}"
echo "ZONE: ${ZONE}"
echo "SKU: ${SKU}"
echo "VERSION: ${VERSION}"
echo "SUBNET: ${SUBNET}"
echo "VNET: ${VNET}"
echo "INFRA_MACHINESET_NAME: ${INFRA_MACHINESET_NAME}"