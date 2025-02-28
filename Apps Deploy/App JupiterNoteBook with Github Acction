# 🚀 Despliegue de Jupyter Notebook en OpenShift con GitHub Actions

## 🔍 Preparación del entorno

Antes de comenzar, necesitarás:

1. Un repositorio de GitHub con tu aplicación Jupyter Notebook
2. Acceso a un clúster OpenShift
3. Una cuenta con permisos para crear aplicaciones en OpenShift

## 📁 Estructura de archivos recomendada

Para un despliegue efectivo, tu repositorio debería contener:

```
├── .github/
│   └── workflows/
│       └── deploy-jupyter.yml
├── notebooks/                   # Tus notebooks de Jupyter
├── requirements.txt             # Dependencias de Python
├── Dockerfile                   # Para construir la imagen
└── openshift/                   # Configuraciones para OpenShift
    ├── deployment.yaml
    ├── service.yaml
    └── route.yaml
```

## 🐳 Creación del Dockerfile

Primero, crea un Dockerfile que construya tu imagen de Jupyter:

```dockerfile
FROM jupyter/scipy-notebook:latest

# Argumentos para la personalización
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

USER root

# Instala dependencias adicionales
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Copia los notebooks
COPY notebooks/ /home/$NB_USER/work/

# Configura permisos para OpenShift
RUN chown -R $NB_USER:$NB_GID /home/$NB_USER/work/ && \
    chmod -R 775 /home/$NB_USER/work/

# Configura para ejecutar como usuario arbitrario en OpenShift
# Esto es importante para la seguridad en OpenShift
RUN chmod -R g+w /home/$NB_USER && \
    fix-permissions /home/$NB_USER

USER $NB_UID

# Puerto por defecto para Jupyter
EXPOSE 8888

# Configura el comando para iniciar sin token/contraseña en entorno de producción
# Adapta según tus necesidades de seguridad
CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--NotebookApp.token=''", "--NotebookApp.password=''"]
```

## ⚙️ Archivos de configuración de OpenShift

### 🔄 `openshift/deployment.yaml`

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

### 🌐 `openshift/service.yaml`

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

### 🔌 `openshift/route.yaml`

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

## 🔄 Flujo de trabajo de GitHub Actions

Ahora, crea el archivo `.github/workflows/deploy-jupyter.yml`:

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
      - main  # o master, según tu configuración

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
          # Reemplazar ${IMAGE_URL} en los archivos YAML
          find openshift -type f -name "*.yaml" -exec sed -i "s|\${IMAGE_URL}|$IMAGE_URL|g" {} \;

      - name: Deploy to OpenShift
        run: |
          # Verificar si ya existe el despliegue
          if oc get deployment ${{ env.APP_NAME }} -n ${{ env.OPENSHIFT_NAMESPACE }} &>/dev/null; then
            echo "Actualizando despliegue existente..."
            oc apply -f openshift/deployment.yaml -n ${{ env.OPENSHIFT_NAMESPACE }}
          else
            echo "Creando nuevo despliegue..."
            oc apply -f openshift/ -n ${{ env.OPENSHIFT_NAMESPACE }}
          fi
          
          # Esperar a que el despliegue esté listo
          oc rollout status deployment/${{ env.APP_NAME }} -n ${{ env.OPENSHIFT_NAMESPACE }} --timeout=300s

      - name: Get Route URL
        if: success()
        run: |
          ROUTE_HOST=$(oc get route ${{ env.APP_NAME }} -n ${{ env.OPENSHIFT_NAMESPACE }} -o jsonpath='{.spec.host}')
          echo "Jupyter Notebook disponible en: https://$ROUTE_HOST"
          echo "NOTEBOOK_URL=https://$ROUTE_HOST" >> $GITHUB_ENV

      - name: Post Deployment Info
        run: |
          echo "✅ Despliegue completado correctamente"
          echo "🔗 Accede a tu Jupyter Notebook: $NOTEBOOK_URL"
```

## 🔐 Configuración de secretos en GitHub

Configura los siguientes secretos en tu repositorio de GitHub:

1. `OPENSHIFT_SERVER`: URL del servidor OpenShift
2. `OPENSHIFT_TOKEN`: Token de acceso a OpenShift
3. `OPENSHIFT_NAMESPACE`: Namespace/proyecto donde desplegar
4. `IMAGE_REGISTRY`: Registro de imágenes (ej. quay.io, registry.redhat.io)
5. `IMAGE_REPOSITORY`: Repositorio dentro del registro
6. `REGISTRY_USERNAME`: Usuario para el registro de imágenes
7. `REGISTRY_PASSWORD`: Contraseña para el registro de imágenes

## 💡 Consideraciones adicionales

### 🛡️ Seguridad

Para un entorno de producción, considera:

- No usar `--NotebookApp.token=''` en el Dockerfile
- Configurar autenticación adecuada para Jupyter
- Utilizar secretos de OpenShift para credenciales sensibles

### 💾 Persistencia

Para datos persistentes, agrega un PersistentVolumeClaim:

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

Y actualiza el deployment para montarlo:

```yaml
volumes:
- name: jupyter-data
  persistentVolumeClaim:
    claimName: jupyter-data
containers:
- name: jupyter-notebook
  # ... otras configuraciones ...
  volumeMounts:
  - mountPath: "/home/jovyan/work/data"
    name: jupyter-data
```

### ⚡ Personalización avanzada

- Agrega extensiones de Jupyter y JupyterLab en el Dockerfile
- Configura variables de entorno para personalizar el comportamiento
- Utiliza ConfigMaps para archivos de configuración