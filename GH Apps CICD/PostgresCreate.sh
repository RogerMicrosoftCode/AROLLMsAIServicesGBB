#!/bin/bash

# Required environment variables
export AZ_RG="arogbbwestus3"          
export AZ_LOCATION="westus3"
export AZ_USER="adminUserGBB"
export UNIQUE="$(date +%s | shasum | head -c 10)gbbpwd."

echo $UNIQUE

# Create PostgreSQL server
az postgres server create \
  --resource-group "${AZ_RG}" \
  --location "${AZ_LOCATION}" \
  --sku-name GP_Gen5_2 \
  --name "microsweeper-${UNIQUE}" \
  --storage-size 51200 \
  --admin-user myAdmin \
  --admin-pass "${AZ_USER}-${UNIQUE}" \
  --public 0.0.0.0