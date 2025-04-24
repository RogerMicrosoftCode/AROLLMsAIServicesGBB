#!/bin/bash

# Required environment variables
AZ_RG="arogbbwestus3"           # Resource group name
AZ_LOCATION="westus3"                  # Server location (Azure region)
AZ_USER="adminUserGBB"                   # Base for admin username
UNIQUE=$(date +%s | sha256sum | base64 | head -c 10)  # Generates a unique suffix
Echo "Creating PostgreSQL server with unique suffix: ${UNIQUE}"

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