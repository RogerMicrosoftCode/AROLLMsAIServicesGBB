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
  name: aro-cluster-abcd1-spot-eastus
spec:
  replicas: 2
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: aro-cluster-abcd1
      machine.openshift.io/cluster-api-machineset: aro-cluster-abcd1-spot-eastus
  template:
    metadata:
        machine.openshift.io/cluster-api-machineset: aro-cluster-abcd1-spot-eastus
    spec:
      providerSpec:
        value:
          spotVMOptions: {}
      taints:
        - effect: NoExecute
          key: spot
          value: 'true'
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