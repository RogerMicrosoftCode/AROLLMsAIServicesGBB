# 📚 Application Examples in Azure Red Hat OpenShift

This guide showcases various application examples that can be deployed in Azure Red Hat OpenShift (ARO) environments. Each example demonstrates different integration patterns with Azure services and deployment methods.

## 📋 Table of Contents

- [🔗 APIM and ARO Pipeline Integration](#-apim-and-aro-pipeline-integration)
- [🎮 Microsweeper Java Application](#-microsweeper-java-application)
- [📊 Jupyter Notebook with GitHub Actions](#-jupyter-notebook-with-github-actions)
- [🧠 MLOps Application Examples](#-mlops-application-examples)
- [🌐 Microsweeper with Azure Front Door](#-microsweeper-with-azure-front-door)
- [🔄 Application with Redis Cache](#-application-with-redis-cache)
- [🔄 GitHub Operations](#-github-operations)

## 🔗 APIM and ARO Pipeline Integration

[View Documentation](APIM-ARO-Integration.md) | [View Script](apim-aro-pipeline-automation.sh)

**Automated pipeline deployment and token configuration between Azure API Management (APIM) and Azure Red Hat OpenShift (ARO)**

This comprehensive automation solution provides:

- **Automated APIM Provisioning** - Deploy and configure Azure API Management instances
- **ARO Integration** - Seamless connection to existing or new ARO clusters
- **Token Management** - Independent configuration and synchronization of authentication tokens
- **Security** - Secure token storage in Azure Key Vault
- **CI/CD Pipelines** - Deploy both GitHub Actions and OpenShift Pipelines (Tekton)
- **Backend Configuration** - Automatic APIM-to-ARO service linking

**Key Features:**
- One-command deployment script
- Environment variable-based configuration
- Token rotation support
- Comprehensive validation and troubleshooting
- Production-ready security practices
- Multi-environment support

**Quick Start:**
```bash
# Configure environment
export AZ_RG="aro-apim-rg"
export AZ_ARO="my-aro-cluster"
export APIM_NAME="my-apim-instance"
export NAMESPACE="api-services"

# Deploy integration
./apim-aro-pipeline-automation.sh deploy
```

## 🎮 Microsweeper Java Application

[View Example](App%20Example%201.md)

A Java application built with Quarkus (Kubernetes Native Java stack) and Azure Database for PostgreSQL, demonstrating:

- Creating and configuring an Azure PostgreSQL database
- Building and deploying a Java application to ARO
- Understanding OpenShift's build and deployment processes
- Exposing applications through OpenShift routes
- Monitoring application metrics

## 📊 Jupyter Notebook with GitHub Actions

[View Example](App%20JupiterNoteBook%20with%20Github%20Acction.md)

A complete guide to deploying Jupyter Notebook environments on OpenShift using CI/CD with GitHub Actions:

- Containerizing Jupyter Notebooks with custom Dockerfile
- Creating OpenShift configuration files (deployment, service, route)
- Setting up GitHub Actions workflow for automated deployment
- Implementing security best practices for Jupyter
- Adding data persistence with PersistentVolumeClaims

## 🧠 MLOps Application Examples

[View Example](App%20MLOps.md)

Comprehensive examples of machine learning operations in ARO, featuring:

- Data science platforms like JupyterHub and Kubeflow
- ML pipeline orchestration
- Model tracking with MLflow
- Model deployment using Seldon Core
- Security and compliance solutions
- Web applications with ML model interfaces
- Large-scale data processing with Spark
- Industry-specific use cases (e-commerce, healthcare)

## 🌐 Microsweeper with Azure Front Door

[View Example](App%20with%20Frontdoor.md)

An extension of the Microsweeper application showcasing integration with Azure Front Door:

- Configuring private ingress controllers in ARO
- Creating custom domain routes
- Implementing edge security with Azure Front Door
- Understanding traffic flow between Microsoft Edge and ARO

## 🔄 Application with Redis Cache

[View Example](App%20with%20RedisCache.md)

Deployment of a voting application that uses Azure Cache for Redis:

- Provisioning Azure Cache for Redis using Azure Service Operator (ASO)
- Deploying a Python/Flask web application
- Configuring application to use Azure Redis for data persistence
- Managing Azure resources directly from OpenShift

## 🔄 GitHub Operations

[View Example](GitHubOperations/README.md)

Integration of GitHub operations with Azure Red Hat OpenShift:

- Setting up GitHub webhooks for OpenShift deployments
- Implementing CI/CD pipelines with GitHub Actions
- Using GitHub as a source for OpenShift builds
- Managing secrets between GitHub and OpenShift
- Automating deployment workflows