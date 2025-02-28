# 🚀 MLOps Application Examples in Azure Red Hat OpenShift (ARO)

## 📊 Data Science Platforms

### 1. JupyterHub on ARO

JupyterHub is an excellent option for data science teams that need to work collaboratively:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jupyterhub
  namespace: mlops-workspace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jupyterhub
  template:
    metadata:
      labels:
        app: jupyterhub
    spec:
      containers:
      - name: jupyterhub
        image: jupyterhub/jupyterhub:latest
        ports:
        - containerPort: 8000
        volumeMounts:
        - name: jupyterhub-data
          mountPath: /srv/jupyterhub
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
      volumes:
      - name: jupyterhub-data
        persistentVolumeClaim:
          claimName: jupyterhub-pvc
```

**Benefits in ARO**:
- High availability thanks to Kubernetes infrastructure
- Integration with Azure Active Directory for authentication
- Elastic scalability for intensive training workloads

## 🔄 ML Pipelines

### 2. Kubeflow on ARO

Kubeflow provides a complete platform for orchestrating ML workflows:

```yaml
apiVersion: kfdef.apps.kubeflow.org/v1
kind: KfDef
metadata:
  name: kubeflow-deployment
  namespace: kubeflow
spec:
  applications:
  - name: jupyter-web-app
    kustomizeConfig:
      repoRef:
        name: manifests
        path: jupyter/jupyter-web-app
  - name: notebook-controller
    kustomizeConfig:
      repoRef:
        name: manifests
        path: jupyter/notebook-controller
  - name: pytorch-operator
    kustomizeConfig:
      repoRef:
        name: manifests
        path: pytorch-job/pytorch-operator
  - name: tf-job-operator
    kustomizeConfig:
      repoRef:
        name: manifests
        path: tf-training/tf-job-operator
  plugins:
  - name: azure
    spec:
      storage:
        kind: azure
```

**Use cases**:
- Automated training-validation-deployment pipelines
- Coordination between different tools (TensorFlow, PyTorch)
- Centralized experiment management

## 🔍 Model Monitoring

### 3. MLflow on ARO

MLflow allows tracking experiments, sharing models, and deploying them:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow-tracking
  namespace: mlops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlflow
  template:
    metadata:
      labels:
        app: mlflow
    spec:
      containers:
      - name: mlflow
        image: mlflow/mlflow:latest
        args:
        - server
        - --backend-store-uri=postgresql://mlflow@postgresql:5432/mlflowdb
        - --default-artifact-root=wasbs://artifacts@storageaccount.blob.core.windows.net/
        - --host=0.0.0.0
        ports:
        - containerPort: 5000
        env:
        - name: AZURE_STORAGE_CONNECTION_STRING
          valueFrom:
            secretKeyRef:
              name: azure-storage
              key: connection-string
```

**Advantages in ARO**:
- Integration with Azure Blob storage for artifacts
- Use of Azure PostgreSQL for metadata storage
- Integrated security and identity management

## 🚢 Model Deployment

### 4. Seldon Core on ARO

Seldon Core facilitates the deployment, monitoring, and updating of ML models:

```yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: credit-risk-model
  namespace: model-serving
spec:
  name: risk-assessment
  predictors:
  - graph:
      children: []
      implementation: SKLEARN_SERVER
      modelUri: wasbs://models@storageaccount.blob.core.windows.net/risk-model/
      name: classifier
    name: default
    replicas: 2
    traffic: 100
```

**Practical applications**:
- Inference API for credit risk models
- A/B deployment to compare model performance
- Data drift monitoring in production

## 🔒 Security and Compliance

### 5. Vault for MLOps Secrets

HashiCorp Vault for managing secrets and credentials:

```yaml
apiVersion: vault.banzaicloud.com/v1alpha1
kind: Vault
metadata:
  name: mlops-vault
  namespace: security
spec:
  size: 1
  image: vault:1.9.2
  bankVaultsImage: banzaicloud/bank-vaults:latest
  config:
    storage:
      azure:
        accountName: "storageAccountName"
        accountKey: "${AZURE_ACCOUNT_KEY}"
    listener:
      tcp:
        address: "0.0.0.0:8200"
        tls_disable: true
  externalConfig:
    policies:
      - name: ml-models
        rules: path "secret/mlops/*" {
                capabilities = ["read", "list"]
              }
    auth:
      - type: kubernetes
        roles:
          - name: ml-pipeline
            bound_service_account_names: ["ml-pipeline-sa"]
            bound_service_account_namespaces: ["mlops"]
            policies: ["ml-models"]
            ttl: 1h
```

**Benefits for sensitive environments**:
- Secure credential management for external APIs
- Automatic secret rotation
- Compliance with PCI, HIPAA, and GDPR requirements

## 🌐 Web Application with ML Model Interface

### 6. Churn Prediction Application with FastAPI and React

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-prediction-ui
  namespace: customer-analytics
spec:
  replicas: 3
  selector:
    matchLabels:
      app: churn-ui
  template:
    metadata:
      labels:
        app: churn-ui
    spec:
      containers:
      - name: frontend
        image: acr.azurecr.io/churn-ui:v1.2
        ports:
        - containerPort: 80
      - name: api
        image: acr.azurecr.io/churn-api:v1.2
        ports:
        - containerPort: 8000
        env:
        - name: MODEL_URI
          value: "azureml://subscriptions/subid/resourcegroups/rg/workspaces/ws/models/churn-model/versions/1"
        - name: AZURE_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: azure-identity
              key: client-id
```

**Industry applications**:
- Predictive customer churn analysis for telecommunications
- Custom interface for marketing teams
- Role-based access control with Azure AD integration

## 📦 Large-Scale Data Processing

### 7. Spark on ARO for Data Processing

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: data-processing-pipeline
  namespace: data-engineering
spec:
  type: Scala
  mode: cluster
  image: acr.azurecr.io/spark:3.2.0
  imagePullPolicy: Always
  mainClass: com.company.data.ProcessingPipeline
  mainApplicationFile: wasbs://jars@storage.blob.core.windows.net/pipeline.jar
  sparkVersion: 3.2.0
  restartPolicy:
    type: OnFailure
    onFailureRetries: 3
  volumes:
    - name: azure-config
      secret:
        secretName: azure-storage-secret
  driver:
    cores: 1
    memory: "2G"
    serviceAccount: spark-sa
  executor:
    cores: 2
    instances: 5
    memory: "4G"
  hadoopConf:
    "fs.azure.account.key.storage.blob.core.windows.net": "STORAGE_ACCOUNT_KEY"
```

**Enterprise applications**:
- ETL processing to feed ML models
- Analysis of large volumes of IoT data
- Preparation of datasets for training

## 💼 Practical Case: Recommendation System for E-Commerce

This complete architecture combines several components to create a personalized recommendation system:

1. **Data ingestion**: Apache Kafka on ARO for event streaming
2. **Processing**: Spark for behavior analysis
3. **Training**: TensorFlow on Kubeflow for recommendation models
4. **Deployment**: Seldon Core for serving the model
5. **Monitoring**: Prometheus and Grafana for performance metrics
6. **Security**: Integration with Azure Key Vault

ARO's elasticity allows scaling resources during intensive training and reducing them during periods of low activity, optimizing costs while maintaining performance.

## 🏥 Specific Case: Medical Image Analysis (HIPAA Compliance)

For healthcare organizations that require strict compliance:

1. **Isolated Environment**: Dedicated virtual network configuration in Azure
2. **Encryption**: Data at rest and in transit encrypted
3. **Access Control**: Integration with Azure AD for role-based authentication and authorization
4. **Auditing**: Logging of all operations for regulatory compliance
5. **Models**: Convolutional neural networks for assisted diagnosis

ARO provides the necessary security and isolation while facilitating collaboration between medical researchers and data scientists.