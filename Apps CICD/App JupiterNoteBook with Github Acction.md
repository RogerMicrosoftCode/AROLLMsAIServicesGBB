# 🚀 Deploying Jupyter Notebook to OpenShift with GitHub Actions

## 🔍 Environment Preparation

Before you begin, you'll need:

1. A GitHub repository with your Jupyter Notebook application
2. Access to an OpenShift cluster
3. An account with permissions to create applications in OpenShift

## 📁 Recommended File Structure

For effective deployment, your repository should contain:

```
├── .github/
│   └── workflows/
│       └── deploy-jupyter.yml
├── notebooks/                   # Your Jupyter notebooks
├── requirements.txt             # Python dependencies
├── Dockerfile                   # To build the image
└── openshift/                   # OpenShift configurations
    ├── deployment.yaml
    ├── service.yaml
    └── route.yaml
```

## 🐳 Creating the Dockerfile

First, create a Dockerfile to build your Jupyter image:

```dockerfile
FROM jupyter/scipy-notebook:latest

# Arguments for customization
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

USER root

# Install additional dependencies
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Copy notebooks
COPY notebooks/ /home/$NB_USER/work/

# Configure permissions for OpenShift
RUN chown -R $NB_USER:$NB_GID /home/$NB_USER/work/ && \
    chmod -R 775 /home/$NB_USER/work/

# Set up to run as arbitrary user in OpenShift
# This is important for security in OpenShift
RUN chmod -R g+w /home/$NB_USER && \
    fix-permissions /home/$NB_USER

USER $NB_UID

# Default port for Jupyter
EXPOSE 8888

# Configure command to start without token/password in production environment
# Adapt according to your security needs
CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--NotebookApp.token=''", "--NotebookApp.password=''"]
```

## ⚙️ OpenShift Configuration Files

### `openshift/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jupyter-notebook
  labels:
    app: jupyter-notebook
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jupyter-notebook
  template:
    metadata:
      labels:
        app: jupyter-notebook
    spec:
      containers:
      - name: jupyter-notebook
        image: ${IMAGE_URL}
        ports:
        - containerPort: 8888
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1"
        env:
        - name: JUPYTER_ENABLE_LAB
          value: "yes"
```

### `openshift/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: jupyter-notebook
spec:
  selector:
    app: jupyter-notebook
  ports:
  - port: 8888
    targetPort: 8888
  type: ClusterIP
```

### `openshift/route.yaml`

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: jupyter-notebook
spec:
  to:
    kind: Service
    name: jupyter-notebook
  port:
    targetPort: 8888
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

## 🔄 GitHub Actions Workflow

Now, create the `.github/workflows/deploy-jupyter.yml` file:

```yaml
name: Deploy Jupyter Notebook to OpenShift

env:
  OPENSHIFT_SERVER: ${{ secrets.OPENSHIFT_SERVER }}
  OPENSHIFT_TOKEN: ${{ secrets.OPENSHIFT_TOKEN }}
  OPENSHIFT_NAMESPACE: ${{ secrets.OPENSHIFT_NAMESPACE }}
  APP_NAME: jupyter-notebook
  IMAGE_REGISTRY: ${{ secrets.IMAGE_REGISTRY }}
  IMAGE_REPOSITORY: ${{ secrets.IMAGE_REPOSITORY }}
  IMAGE_TAG: ${{ github.sha }}

on:
  push:
    branches:
      - main  # or master, depending on your configuration

jobs:
  build-and-deploy:
    name: Build and Deploy Jupyter Notebook
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.IMAGE_REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_REPOSITORY }}/${{ env.APP_NAME }}:${{ env.IMAGE_TAG }},${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_REPOSITORY }}/${{ env.APP_NAME }}:latest

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

      - name: Set IMAGE_URL environment variable
        run: |
          echo "IMAGE_URL=${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_REPOSITORY }}/${{ env.APP_NAME }}:${{ env.IMAGE_TAG }}" >> $GITHUB_ENV

      - name: Process template files
        run: |
          # Replace ${IMAGE_URL} in YAML files
          find openshift -type f -name "*.yaml" -exec sed -i "s|\${IMAGE_URL}|$IMAGE_URL|g" {} \;

      - name: Deploy to OpenShift
        run: |
          # Check if deployment already exists
          if oc get deployment ${{ env.APP_NAME }} -n ${{ env.OPENSHIFT_NAMESPACE }} &>/dev/null; then
            echo "Updating existing deployment..."
            oc apply -f openshift/deployment.yaml -n ${{ env.OPENSHIFT_NAMESPACE }}
          else
            echo "Creating new deployment..."
            oc apply -f openshift/ -n ${{ env.OPENSHIFT_NAMESPACE }}
          fi
          
          # Wait for deployment to be ready
          oc rollout status deployment/${{ env.APP_NAME }} -n ${{ env.OPENSHIFT_NAMESPACE }} --timeout=300s

      - name: Get Route URL
        if: success()
        run: |
          ROUTE_HOST=$(oc get route ${{ env.APP_NAME }} -n ${{ env.OPENSHIFT_NAMESPACE }} -o jsonpath='{.spec.host}')
          echo "Jupyter Notebook available at: https://$ROUTE_HOST"
          echo "NOTEBOOK_URL=https://$ROUTE_HOST" >> $GITHUB_ENV

      - name: Post Deployment Info
        run: |
          echo "✅ Deployment completed successfully"
          echo "🔗 Access your Jupyter Notebook: $NOTEBOOK_URL"
```

## 🔐 Setting up GitHub Secrets

Configure the following secrets in your GitHub repository:

1. `OPENSHIFT_SERVER`: OpenShift server URL
2. `OPENSHIFT_TOKEN`: OpenShift access token
3. `OPENSHIFT_NAMESPACE`: Namespace/project for deployment
4. `IMAGE_REGISTRY`: Image registry (e.g., quay.io, registry.redhat.io)
5. `IMAGE_REPOSITORY`: Repository within the registry
6. `REGISTRY_USERNAME`: Username for the image registry
7. `REGISTRY_PASSWORD`: Password for the image registry

## 💡 Additional Considerations

### 🛡️ Security

For a production environment, consider:

- Not using `--NotebookApp.token=''` in the Dockerfile
- Setting up proper authentication for Jupyter
- Using OpenShift secrets for sensitive credentials

### 💾 Persistence

For persistent data, add a PersistentVolumeClaim:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jupyter-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

And update the deployment to mount it:

```yaml
volumes:
- name: jupyter-data
  persistentVolumeClaim:
    claimName: jupyter-data
containers:
- name: jupyter-notebook
  # ... other configurations ...
  volumeMounts:
  - mountPath: "/home/jovyan/work/data"
    name: jupyter-data
```

### ✨ Advanced Customization

- Add Jupyter and JupyterLab extensions in the Dockerfile
- Configure environment variables to customize behavior
- Use ConfigMaps for configuration files