# K8s Cluster on AWS — Architecture Description

> **Project**: Self-managed Kubernetes cluster on AWS  
> **Region**: `ap-southeast-1` (Singapore)  
> **Last Updated**: April 2026

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Network Architecture](#2-network-architecture)
3. [Compute Resources](#3-compute-resources)
4. [Load Balancing](#4-load-balancing)
5. [Security](#5-security)
6. [IAM & Permissions](#6-iam--permissions)
7. [Software Stack](#7-software-stack)
8. [Traffic Flow](#8-traffic-flow)

---

## 1. Architecture Overview

This infrastructure provisions a **self-managed, multi-master Kubernetes cluster** on AWS using `kubeadm`. The design separates the control plane and data plane across public and private subnets with an Nginx TCP proxy acting as both **Kubernetes API load balancer** and **SSH bastion host**. An **AWS Application Load Balancer (ALB)** serves as the internet-facing entry point for HTTP traffic.

### High-Level Topology

```
Internet
   │
   ▼
┌─────────────────────────────────────────────────────────────────┐
│  AWS ALB (k8s-main-alb) — Layer 7, Internet-facing, HTTP :80   │
│  Spans: public-subnet (AZ-a), public-subnet-1 (AZ-b),         │
│         public-subnet-forALB                                    │
└─────────────┬───────────────────────────────────────────────────┘
              │ forward to Target Group (NodePort :32222)
              ▼
┌─────────────────────────────────────────────────────────────────┐
│  VPC: dattran-vpc                                               │
│                                                                 │
│  ┌── Public Subnet (AZ-a) ───────────────────────────────────┐  │
│  │  • k8s_nginx_lb  (Nginx TCP Proxy + Bastion)              │  │
│  │  • k8s_master    (K8s Master 1 — Primary Control Plane)   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌── Private Subnet (AZ-a) ──────────────────────────────────┐  │
│  │  • k8s_master_2   (K8s Master 2 — HA Control Plane)       │  │
│  │  • k8s_worker-0 … k8s_worker-2  (3 Worker Nodes)         │  │
│  │  • k8s_nfs × 2    (NFS Storage Servers)                   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Network Architecture

### VPC

| Attribute     | Value             |
|---------------|-------------------|
| **Name**      | `dattran-vpc`     |
| **Region**    | `ap-southeast-1`  |

### Subnets

| Subnet Name                   | Type    | AZ    | Used By                                     |
|-------------------------------|---------|-------|----------------------------------------------|
| `public-subnet`               | Public  | AZ-a  | Nginx LB, Master 1, ALB                     |
| `public-subnet-1`             | Public  | AZ-b  | ALB (Multi-AZ)                               |
| `public-subnet-forALB`        | Public  | —     | ALB (Multi-AZ)                               |
| `private-subnet-1(real)`      | Private | AZ-a  | Master 2, Workers (×3), NFS Servers (×2)     |

### Connectivity Pattern

- **Public subnet** instances have public IPs and direct internet access.
- **Private subnet** instances have **no public IPs**. They are accessed via:
  - **SSH**: Through the Nginx LB acting as a **bastion host**.
  - **Internet egress**: Via a NAT Gateway.

---

## 3. Compute Resources

All EC2 instances use **Ubuntu AMI** and the `k8s` SSH key pair.

### 3.1 Nginx Load Balancer / Bastion

| Attribute           | Value                                        |
|---------------------|----------------------------------------------|
| **Instance Type**   | `t2.medium`                                  |
| **Root Volume**     | 10 GB `gp3`                                 |
| **Subnet**          | `public-subnet` (public IP)                  |
| **Security Group**  | `k8s_nginx_lb_sg`                            |
| **Roles**           | Nginx TCP proxy for K8s API (:6443), SSH bastion for private subnet nodes, Docker host, FileBrowser |

**Purpose**: Acts as the single entry point for `kubectl` commands by proxying TCP `:6443` to both master nodes. Also serves as the SSH bastion host for all private-subnet instances.

### 3.2 Kubernetes Master 1 (Primary)

| Attribute           | Value                                          |
|---------------------|-------------------------------------------------|
| **Instance Type**   | `t2.medium`                                     |
| **Root Volume**     | 50 GB `gp3`                                    |
| **Subnet**          | `public-subnet` (public IP)                     |
| **Security Group**  | `k8s_master_sg`                                 |
| **IAM Profile**     | `k8s-node-ebs-profile` (EBS CSI Driver access)  |
| **IMDSv2**          | Enabled, hop limit = 2                          |

**Purpose**: Initializes the Kubernetes cluster via `kubeadm init`. Hosts the primary control plane components (API Server, etcd, Controller Manager, Scheduler). Runs additional management tools.

**Deployed Software**:
- Docker
- Kubernetes control plane (`kubeadm init`)
- Rancher (cluster management UI)
- ArgoCD (GitOps continuous delivery)
- Helm (package manager)
- AWS EBS CSI Driver (dynamic EBS volume provisioning)
- Prometheus & Grafana (monitoring stack, namespace: `monitoring`)
- Elasticsearch (logging stack, namespace: `logging`)

### 3.3 Kubernetes Master 2 (HA)

| Attribute           | Value                                          |
|---------------------|-------------------------------------------------|
| **Instance Type**   | `t2.medium`                                     |
| **Root Volume**     | 20 GB `gp3`                                    |
| **Subnet**          | `private-subnet-1(real)` (**no public IP**)      |
| **Security Group**  | `k8s_master_sg`                                 |
| **IAM Profile**     | `k8s-node-ebs-profile`                          |
| **SSH Access**      | Via Nginx LB bastion                            |

**Purpose**: Joins the cluster as a second control-plane node for **high availability**. Its private IP is added to the Nginx TCP upstream for API load balancing.

### 3.4 Kubernetes Workers (×3)

| Attribute           | Value                                          |
|---------------------|-------------------------------------------------|
| **Instance Type**   | `t2.medium`                                     |
| **Root Volume**     | 20 GB `gp3`                                    |
| **Subnet**          | `private-subnet-1(real)` (**no public IP**)      |
| **Security Group**  | `k8s_worker_sg`                                 |
| **IAM Profile**     | `k8s-node-ebs-profile`                          |
| **SSH Access**      | Via Nginx LB bastion                            |

**Purpose**: Run application workloads. Each worker joins the cluster using a join command generated by the master node. Workers expose services via **NodePort `:32222`** (mapped to the Ingress Controller).

### 3.5 NFS Servers (×2)

| Attribute           | Value                                          |
|---------------------|-------------------------------------------------|
| **Instance Type**   | `t2.medium`                                     |
| **Root Volume**     | 30 GB `gp3`                                    |
| **Subnet**          | `private-subnet-1(real)` (**no public IP**)      |
| **Security Group**  | `k8s_nfs`                                       |
| **SSH Access**      | Via Master 1 as proxy                           |

**Purpose**: Provide **NFS-based persistent storage** (`PersistentVolume` / `PersistentVolumeClaim`) for the Kubernetes cluster.

---

## 4. Load Balancing

### 4.1 AWS Application Load Balancer (ALB)

| Attribute           | Value                                                         |
|---------------------|---------------------------------------------------------------|
| **Name**            | `k8s-main-alb`                                               |
| **Type**            | Application (Layer 7)                                         |
| **Scheme**          | Internet-facing                                               |
| **Subnets**         | `public-subnet`, `public-subnet-1`, `public-subnet-forALB`   |
| **Security Group**  | `k8s_nginx_lb_sg`                                             |

### 4.2 Target Group

| Attribute           | Value                              |
|---------------------|-------------------------------------|
| **Name**            | `k8s-tg-lb`                        |
| **Protocol/Port**   | HTTP / 80                          |
| **Target Port**     | 32222 (NodePort on workers)        |
| **Targets**         | All 3 worker nodes                 |

### 4.3 Listener

| Attribute           | Value                              |
|---------------------|-------------------------------------|
| **Port/Protocol**   | 80 / HTTP                          |
| **Action**          | Forward to `k8s-tg-lb`            |

### 4.4 Nginx TCP Proxy (Internal K8s API LB)

The `k8s_nginx_lb` instance runs Nginx with a **stream (L4) configuration** that load-balances `kubectl` / API calls across both master nodes:

```nginx
upstream k8s_api {
    server <master_1_private_ip>:6443;
    server <master_2_private_ip>:6443;
}
server {
    listen 6443;
    proxy_pass k8s_api;
}
```

---

## 5. Security

### 5.1 Security Groups

#### `k8s_nginx_lb_sg` (Nginx LB / ALB)

| Direction | Protocol | Port(s)       | Source          | Purpose                 |
|-----------|----------|---------------|-----------------|-------------------------|
| Ingress   | TCP      | 22            | `0.0.0.0/0`    | SSH access              |
| Ingress   | TCP      | 80            | `0.0.0.0/0`    | HTTP                    |
| Ingress   | TCP      | 443           | `0.0.0.0/0`    | HTTPS                   |
| Ingress   | TCP      | 6443          | `0.0.0.0/0`    | Kubernetes API           |
| Ingress   | TCP      | 9991          | `0.0.0.0/0`    | Jenkins                 |
| Ingress   | TCP      | 30000–32767   | `0.0.0.0/0`    | NodePort range          |
| Egress    | All      | All           | `0.0.0.0/0`    | Allow all outbound      |

#### `k8s_master_sg` (Masters)

| Direction | Protocol | Port(s)       | Source              | Purpose                  |
|-----------|----------|---------------|---------------------|--------------------------|
| Ingress   | TCP      | 22            | `0.0.0.0/0`        | SSH access               |
| Ingress   | TCP      | 80, 443       | `0.0.0.0/0`        | HTTP / HTTPS             |
| Ingress   | TCP      | 81            | `0.0.0.0/0`        | Rancher HTTP             |
| Ingress   | TCP      | 444           | `0.0.0.0/0`        | Rancher HTTPS            |
| Ingress   | TCP      | 6443          | `0.0.0.0/0`        | Kubernetes API Server    |
| Ingress   | TCP      | 2379–2380     | `0.0.0.0/0`        | etcd cluster             |
| Ingress   | TCP      | 6783          | `0.0.0.0/0`        | Weavenet TCP             |
| Ingress   | UDP      | 6784          | `0.0.0.0/0`        | Weavenet UDP             |
| Ingress   | UDP      | 8472          | `0.0.0.0/0`        | Flannel VXLAN            |
| Ingress   | UDP      | 8285          | `0.0.0.0/0`        | Flannel backend          |
| Ingress   | TCP      | 8080          | `0.0.0.0/0`        | HTTP alt                 |
| Ingress   | TCP      | 10248–10260   | `0.0.0.0/0`        | Kubelet & control plane  |
| Ingress   | TCP      | 30000–32767   | `0.0.0.0/0`        | NodePort range           |
| Ingress   | TCP      | 0–65535       | `k8s_nginx_lb_sg`  | All TCP from Nginx LB    |
| Egress    | All      | All           | `0.0.0.0/0`        | Allow all outbound       |

#### `k8s_worker_sg` (Workers)

| Direction | Protocol | Port(s)       | Source              | Purpose                  |
|-----------|----------|---------------|---------------------|--------------------------|
| Ingress   | TCP      | 22            | `0.0.0.0/0`        | SSH access               |
| Ingress   | TCP      | 80, 443       | `0.0.0.0/0`        | HTTP / HTTPS             |
| Ingress   | TCP      | 6443          | `0.0.0.0/0`        | Kubernetes API           |
| Ingress   | TCP      | 2379–2380     | `0.0.0.0/0`        | etcd                     |
| Ingress   | TCP      | 6783          | `0.0.0.0/0`        | Weavenet TCP             |
| Ingress   | UDP      | 6784          | `0.0.0.0/0`        | Weavenet UDP             |
| Ingress   | UDP      | 8472          | `0.0.0.0/0`        | Flannel VXLAN            |
| Ingress   | UDP      | 8285          | `0.0.0.0/0`        | Flannel backend          |
| Ingress   | TCP      | 8080          | `0.0.0.0/0`        | HTTP alt                 |
| Ingress   | TCP      | 10248–10260   | `0.0.0.0/0`        | Kubelet & control plane  |
| Ingress   | TCP      | 30000–32767   | `0.0.0.0/0`        | NodePort range           |
| Ingress   | TCP      | 0–65535       | `k8s_nginx_lb_sg`  | All TCP from Nginx LB    |
| Egress    | All      | All           | `0.0.0.0/0`        | Allow all outbound       |

#### `k8s_nfs` (NFS Servers)

| Direction | Protocol | Port(s) | Source              | Purpose                  |
|-----------|----------|---------|---------------------|--------------------------|
| Ingress   | All      | All     | `k8s-vpn-sg`       | VPN access               |
| Ingress   | All      | All     | `k8s_master_sg`    | Master access            |
| Ingress   | All      | All     | `k8s_worker_sg`    | Worker access            |
| Ingress   | All      | All     | `0.0.0.0/0`        | Open inbound (all)       |
| Egress    | All      | All     | `0.0.0.0/0`        | Allow all outbound       |

### 5.2 Key Pair

| Attribute     | Value          |
|---------------|----------------|
| **Name**      | `k8s`          |
| **Public Key**| `k8s.pub`      |
| **Private Key**| `k8s.pem`     |
| **Used By**   | All EC2 instances |

---

## 6. IAM & Permissions

### IAM Role: `k8s-node-ebs-role-1`

- **Trusted Principal**: `ec2.amazonaws.com` (allows EC2 service to assume this role)
- **Attached Policy**: `AmazonEBSCSIDriverPolicy` — grants permissions for the **AWS EBS CSI Driver** to create, attach, detach, and delete EBS volumes dynamically.

### Instance Profile: `k8s-node-ebs-profile`

Assigned to: **Master 1, Master 2, all Workers, and NFS Servers**.

This enables Pods running the EBS CSI controller to interact with the AWS API for **dynamic Persistent Volume provisioning** using the `gp3` storage class.

---

## 7. Software Stack

### Kubernetes Cluster

| Component                | Details                                         |
|--------------------------|------------------------------------------------|
| **Bootstrapping**        | `kubeadm init` on Master 1                     |
| **Container Runtime**    | Docker                                          |
| **CNI Plugin**           | Flannel (VXLAN) + Weavenet (ports open)         |
| **Ingress Controller**   | Exposed via NodePort `:32222` on workers        |
| **Storage**              | AWS EBS CSI Driver (`gp3` StorageClass) + NFS  |

### Platform Services

| Service            | Namespace     | Description                             |
|--------------------|---------------|-----------------------------------------|
| **Rancher**        | —             | Kubernetes management UI                |
| **ArgoCD**         | `argocd`      | GitOps continuous delivery              |
| **Prometheus**     | `monitoring`  | Metrics collection                      |
| **Grafana**        | `monitoring`  | Metrics visualization / dashboards      |
| **Elasticsearch**  | `logging`     | Log aggregation and search              |
| **FileBrowser**    | —             | Web-based file manager on Nginx LB      |
| **EBS CSI Driver** | `kube-system` | Dynamic EBS volume provisioner          |

---

## 8. Traffic Flow

### 8.1 Inbound HTTP Traffic (User → Application)

```
User Browser
  │
  ▼  HTTP :80
AWS ALB (k8s-main-alb)
  │
  ▼  Forward
Target Group (k8s-tg-lb)
  │
  ├──▶ Worker-0 :32222 (NodePort)
  ├──▶ Worker-1 :32222 (NodePort)
  └──▶ Worker-2 :32222 (NodePort)
         │
         ▼
   Ingress Controller → ClusterIP Service → Pod
```

### 8.2 kubectl / API Traffic (Admin → K8s API)

```
Admin Workstation
  │
  ▼  TCP :6443
Nginx LB (k8s_nginx_lb) — Public IP
  │
  ├──▶ Master 1 :6443 (Public Subnet)
  └──▶ Master 2 :6443 (Private Subnet)
```

### 8.3 SSH Access to Private Nodes

```
Admin Workstation
  │
  ▼  SSH :22
Nginx LB (Bastion) — Public IP
  │
  ├──▶ Master 2  (private IP via bastion_host)
  ├──▶ Worker-0  (private IP via bastion_host)
  ├──▶ Worker-1  (private IP via bastion_host)
  ├──▶ Worker-2  (private IP via bastion_host)
  └──▶ NFS × 2   (private IP via proxy through Master 1)
```

### 8.4 NFS Storage Access

```
Worker Pods (PVC mount)
  │
  ▼  NFS :2049
NFS Servers (private subnet)
  │
  ▼
  Local gp3 disk (30 GB each)
```

---

## Architecture Diagram

For visual representations, see [`infrastructure-diagram.md`](./infrastructure-diagram.md) which includes:

- **Mermaid** diagram (GitHub, Notion, Obsidian compatible)
- **draw.io XML** (import into app.diagrams.net)
- **PlantUML** (plantuml.com or VS Code extension)

The raw `.drawio` file is at [`infrastructure-diagram.drawio`](./infrastructure-diagram.drawio).
