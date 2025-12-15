# APIM-ARO Pipeline Automation - Quick Reference

## 🚀 One-Line Commands

### Deploy Complete Integration
```bash
./apim-aro-pipeline-automation.sh deploy
```

### Validate Existing Setup
```bash
./apim-aro-pipeline-automation.sh validate
```

### Cleanup All Resources
```bash
./apim-aro-pipeline-automation.sh cleanup
```

### Show Help
```bash
./apim-aro-pipeline-automation.sh help
```

## ⚙️ Essential Environment Variables

```bash
# Minimum required configuration
export AZ_RG="my-resource-group"
export AZ_ARO="my-aro-cluster"
export APIM_NAME="my-apim-instance"
export NAMESPACE="api-services"
```

## 🔑 Retrieve Tokens

```bash
# Get ARO Service Account Token from Key Vault
az keyvault secret show \
  --vault-name kv-<unique-id> \
  --name aro-sa-token \
  --query value -o tsv

# Get APIM Subscription Key from Key Vault
az keyvault secret show \
  --vault-name kv-<unique-id> \
  --name apim-subscription-key \
  --query value -o tsv
```

## 📊 Status Checks

```bash
# Check APIM Status
az apim show --name $APIM_NAME --resource-group $AZ_RG --query provisioningState

# Check ARO Connection
oc whoami

# List Namespace Resources
oc get all -n $NAMESPACE

# View Service Accounts
oc get sa -n $NAMESPACE
```

## 🔧 Common Troubleshooting

### Reset ARO Connection
```bash
# Get fresh credentials
ADMIN_CREDS=$(az aro list-credentials --name $AZ_ARO --resource-group $AZ_RG)
OCP_API=$(az aro show --name $AZ_ARO --resource-group $AZ_RG --query apiserverProfile.url -o tsv)

# Re-login
oc login $OCP_API -u $(echo $ADMIN_CREDS | jq -r '.kubeadminUsername') \
  -p $(echo $ADMIN_CREDS | jq -r '.kubeadminPassword') --insecure-skip-tls-verify=true
```

### Regenerate Service Account Token
```bash
# Delete old token secret
oc delete secret apim-integration-sa-token -n $NAMESPACE

# Create new token
oc create token apim-integration-sa -n $NAMESPACE --duration=87600h
```

### Check APIM APIs
```bash
# List all APIs
az apim api list --resource-group $AZ_RG --service-name $APIM_NAME -o table

# Show specific API
az apim api show --resource-group $AZ_RG --service-name $APIM_NAME --api-id aro-backend-api
```

## 🎯 Testing Integration

### Test ARO Route
```bash
# Get route URL
ROUTE_URL=$(oc get route -n $NAMESPACE -o jsonpath='{.items[0].spec.host}')

# Test endpoint
curl -k https://$ROUTE_URL/health
```

### Test APIM Gateway
```bash
# Get APIM gateway URL
APIM_URL=$(az apim show --name $APIM_NAME --resource-group $AZ_RG --query gatewayUrl -o tsv)

# Test with subscription key
curl -H "Ocp-Apim-Subscription-Key: <your-key>" ${APIM_URL}/api/v1/health
```

## 📦 Pipeline Operations

### Trigger GitHub Actions
```bash
# Push to main branch triggers deployment
git push origin main

# Or manually trigger via GitHub UI
```

### Run OpenShift Pipeline
```bash
# Create pipeline run
oc create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: apim-aro-pipeline-run-
  namespace: $NAMESPACE
spec:
  pipelineRef:
    name: apim-aro-pipeline
  params:
    - name: APP_NAME
      value: backend-api
    - name: GIT_REPO
      value: https://github.com/yourusername/repo.git
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi
EOF

# Watch pipeline progress
tkn pipelinerun logs -f -n $NAMESPACE
```

## 🔐 Security Operations

### Update RBAC
```bash
# Grant additional permissions
oc adm policy add-role-to-user admin system:serviceaccount:$NAMESPACE:apim-integration-sa
```

### Rotate Credentials
```bash
# Delete and recreate service account
oc delete sa apim-integration-sa -n $NAMESPACE
oc create sa apim-integration-sa -n $NAMESPACE

# Re-run token generation
./apim-aro-pipeline-automation.sh deploy
```

## 📈 Monitoring

### View APIM Metrics
```bash
# Request count
az monitor metrics list \
  --resource $(az apim show --name $APIM_NAME --resource-group $AZ_RG --query id -o tsv) \
  --metric Requests \
  --start-time 2025-01-01T00:00:00Z

# Response time
az monitor metrics list \
  --resource $(az apim show --name $APIM_NAME --resource-group $AZ_RG --query id -o tsv) \
  --metric Duration
```

### View ARO Logs
```bash
# Deployment logs
oc logs deployment/$APP_NAME -n $NAMESPACE --tail=100 -f

# Recent events
oc get events -n $NAMESPACE --sort-by='.lastTimestamp' | head -20
```

## 🗑️ Cleanup Commands

### Delete Individual Resources
```bash
# Delete APIM
az apim delete --name $APIM_NAME --resource-group $AZ_RG --yes

# Delete ARO namespace
oc delete project $NAMESPACE

# Delete Key Vault
az keyvault delete --name kv-<unique-id> --resource-group $AZ_RG
```

### Complete Cleanup
```bash
# Use script cleanup command
./apim-aro-pipeline-automation.sh cleanup

# Or delete entire resource group
az group delete --name $AZ_RG --yes --no-wait
```

## 📞 Support Resources

- **Script Documentation**: [APIM-ARO-Integration.md](APIM-ARO-Integration.md)
- **GitHub Issues**: [Report Issue](https://github.com/RogerMicrosoftCode/AROLLMsAIServicesGBB/issues)
- **Azure Support**: [Azure Portal](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)
- **OpenShift Docs**: [docs.openshift.com](https://docs.openshift.com)

---

💡 **Tip**: Save this file for quick access to common commands during operations!
