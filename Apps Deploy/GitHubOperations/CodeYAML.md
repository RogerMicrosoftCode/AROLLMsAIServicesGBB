name: Build and push image to Azure Container Registry

env:
  OPENSHIFT_SERVER: ${{ secrets.OPENSHIFT_SERVER }}
  OPENSHIFT_TOKEN: ${{ secrets.OPENSHIFT_TOKEN }}
  OPENSHIFT_NAMESPACE: "pharmarun-dev"  # Replace with your namespace
  APP_NAME: "your-app-name"  # Replace with your application name
  SERVICE_NAME: "your-service-name"  # Replace with your service name

on:
  push:
    branches:
      - master

jobs:
  build:
    name: Build and push image to Azure Container Registry
    runs-on: ubuntu-latest
    steps:
      - name: Check out code
        uses: actions/checkout@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1

      - name: Log in to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Login to Azure Container Registry
        uses: azure/docker-login@v1
        with:
          login-server: ${{ secrets.ACR_LOGIN_SERVER }}
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}

      - name: Build and push image to ACR
        env:
          ACR_REGISTRY: ${{ secrets.ACR_LOGIN_SERVER }}
          ACR_REPOSITORY: your-acr-repository-name  # Replace with your repository name
          IMAGE_TAG: ${{ github.sha }}
        run: |
          # Build and push using the repository URI
          docker build -t $ACR_REGISTRY/$ACR_REPOSITORY:$IMAGE_TAG .
          docker push $ACR_REGISTRY/$ACR_REPOSITORY:$IMAGE_TAG
          
          # Tag as latest as well
          docker tag $ACR_REGISTRY/$ACR_REPOSITORY:$IMAGE_TAG $ACR_REGISTRY/$ACR_REPOSITORY:latest
          docker push $ACR_REGISTRY/$ACR_REPOSITORY:latest
          
          # Save the image URI for the deployment step
          echo "IMAGE_URI=$ACR_REGISTRY/$ACR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_ENV

      - name: Install OpenShift CLI
        uses: redhat-actions/openshift-tools-installer@v1
        with:
          oc: 4

      - name: Log in to OpenShift
        uses: redhat-actions/oc-login@v1
        with:
          openshift_server_url: ${{ env.OPENSHIFT_SERVER }}
          openshift_token: ${{ env.OPENSHIFT_TOKEN }}
          insecure_skip_tls_verify: true
          namespace: ${{ env.OPENSHIFT_NAMESPACE }}

      - name: Deploy to OpenShift
        run: |
          # Update the deployment with the new image
          oc set image deployment/${SERVICE_NAME} ${SERVICE_NAME}=${IMAGE_URI} -n ${OPENSHIFT_NAMESPACE}
          
          # Trigger a rollout
          oc rollout restart deployment/${SERVICE_NAME} -n ${OPENSHIFT_NAMESPACE}
          
          # Wait for rollout to complete
          oc rollout status deployment/${SERVICE_NAME} -n ${OPENSHIFT_NAMESPACE} --timeout=300s
          
          # Verify the deployment
          echo "Getting pod status..."
          oc get pods -l app=${SERVICE_NAME} -n ${OPENSHIFT_NAMESPACE}