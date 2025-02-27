# Configuring GitHub Secrets

To securely pass the OpenShift credentials to the GitHub Action workflow, you need to configure GitHub Secrets:

1. Go to your GitHub repository and navigate to the "Settings" tab.
2. Click on "Secrets" and then "New repository secret".
3. Add the OpenShift server URL and token as secrets. Use the same names as referenced in the workflow file:
   - `OPENSHIFT_SERVER`
   - `OPENSHIFT_NAMESPACE`
   - `OPENSHIFT_TOKEN`