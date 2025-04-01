# Kubernetes Services Comparison Table

This table provides a detailed comparison between different Kubernetes services: OCP On-Premise, ARO (Azure Red Hat OpenShift), Oracle Cloud Infrastructure Kubernetes Engine (OKE), Azure Kubernetes Service (AKS), and Google Kubernetes Engine (GKE).

## General Comparison

| Category | OCP On-Premise | ARO | Oracle | AKS | GKE |
|-----------|----------------|-----|--------|-----|-----|
| **Critical Ops** |||||
| Service Mesh | Istio | Red Hat Service Mesh (based on Istio) | Service Mesh | Istio/Linkerd/Open Service Mesh | Istio/Traffic Director/Cloud Service Mesh |
| Registry | Registry | Red Hat Quay/Azure Container Registry | Registry | Azure Container Registry | Artifact Registry/Container Registry |
| Monitoring | Prometheus/Grafana, Logging Operator | Integrated Prometheus/Grafana, Cluster Logging, Azure Monitor | OCI O&M platform services, OCI Logging Analytics | Azure Monitor, Container Insights | Cloud Monitoring, Cloud Logging, Cloud Trace |
| **Security and Auth** |||||
| Authentication | Kubernetes native | Integrated OAuth, Azure AD integration | Security | Azure AD Integration | Google Cloud IAM |
| Authorization | Internal/Provider | OpenShift RBAC, Azure RBAC | IAM | Azure RBAC, Kubernetes RBAC | IAM, Kubernetes RBAC, Binary Authorization |
| **Day 2 Operations** |||||
| UI | OCP UI, console.redhat.com | OpenShift web console, Azure Portal, Azure CLI | OKE Clusters UI | Azure Portal, Azure CLI | Google Cloud Console, Cloud SDK, GKE Hub |
| Updates and Roadmap | Updates managed by Red Hat, support for ~12 months per version | Managed updates and update channels, support for up to 18 months per version, 99.95% SLA | Updates managed by Oracle, 3-4 supported versions | Automated updates, support for N-2 versions, ~12 months lifecycle per version | Auto-upgrade, support for multiple versions, automated patching cycle, SLA up to 99.95% |
| **Kubernetes** |||||
| Container Orchestration | Kubernetes Engine | OpenShift Container Platform on Azure | OKE | Managed Kubernetes | Managed Kubernetes |
| **Infrastructure** |||||
| Networking | OVN | OVN/SDN, Azure VNet integration | Network | Azure CNI, Kubenet | VPC-native/kubenet, Cloud CDN, Cloud Load Balancing |
| Operating System | Core OS | Red Hat Enterprise Linux CoreOS (RHCOS) | Oracle Linux | Ubuntu, Windows Server (nodes) | Container-Optimized OS, Ubuntu, Windows Server (nodes) |
| Hosting | On-Prem | Azure (fully managed service) | OCI | Azure | Google Cloud Platform |
| Cloud Services Integration | Cloud-independent, integrations via operators | Native integration with Azure services, access to Red Hat Marketplace | Deep integration with OCI services, limited with other providers | Native integration with +200 Azure services, Azure Arc for multi-cloud services | Native integration with GCP services, Anthos for multi-cloud/on-prem |
| GPU Support | Limited, requires manual configuration | Yes, through Azure N-series VMs | Yes, through OCI GPU shapes | Yes, integration with Azure GPU VMs | Yes, native support for GPU and TPU |
| Spot/Ephemeral Instances | Not native | Yes, support for Azure Spot VMs | Yes, preemptible instances | Yes, Azure Spot VMs with VMSS integration | Yes, Spot VMs and Preemptible VMs |
| **People** |||||
| Support | Local Engineers | Red Hat SRE + Azure Support (collaborative support, joint SLA) | Oracle Support | Microsoft Azure Support | Google Cloud Support |