# K8s AWS Infrastructure — Diagram as Code

Paste the blocks below into the supported platforms.

---

## 1. Mermaid (paste into mermaid.live, Notion, GitHub, GitLab, Obsidian)

```mermaid
graph TB
    %% ─── Styling ───────────────────────────────────────────────────────
    classDef internet  fill:#1a1a2e,stroke:#4fc3f7,color:#4fc3f7,stroke-width:2px
    classDef alb       fill:#FF9900,stroke:#e65100,color:#fff,stroke-width:2px
    classDef tg        fill:#f57c00,stroke:#e65100,color:#fff
    classDef nginx     fill:#009688,stroke:#00695c,color:#fff,stroke-width:2px
    classDef master    fill:#7b1fa2,stroke:#4a0072,color:#fff,stroke-width:2px
    classDef worker    fill:#1565c0,stroke:#0d47a1,color:#fff,stroke-width:2px
    classDef nfs       fill:#2e7d32,stroke:#1b5e20,color:#fff,stroke-width:2px
    classDef pubsub    fill:#fff3e0,stroke:#FF9900,color:#333,stroke-dasharray:5 5
    classDef privsub   fill:#e3f2fd,stroke:#1565c0,color:#333,stroke-dasharray:5 5
    classDef vpc       fill:#f1f8e9,stroke:#33691e,color:#333,stroke-width:3px
    classDef sg        fill:#fce4ec,stroke:#c62828,color:#c62828,stroke-dasharray:3 3
    classDef iam       fill:#fff8e1,stroke:#f9a825,color:#333

    %% ─── Entry ─────────────────────────────────────────────────────────
    INTERNET(["🌐 Internet\n(HTTP :80)"]):::internet

    subgraph AWS ["☁️  AWS — ap-southeast-1"]

        subgraph VPC ["🟩 VPC · dattran_vpc"]

            subgraph PUB ["─── Public Subnets ───"]
                direction TB

                subgraph SUB_PUB1 ["📦 dattran_subnet (AZ-a)"]
                    ALB["⚖️  k8s-main-alb\nApplication Load Balancer\nInternet-facing · Layer 7"]:::alb
                    TG["🎯 k8s-tg-lb\nTarget Group\nHTTP :80 → NodePort :32222"]:::tg
                    NGINX["🔀 k8s_nginx_lb\nt3.small · 10 GB gp3\nNginx TCP Proxy + Bastion\nFileBrowser · Docker"]:::nginx
                    MASTER["☸️  k8s_master\nt3.medium · 50 GB gp3\nIMDSv2 · IAM Profile\nkubeadm init · Rancher\nArgoCD · Prometheus\nGrafana · Helm · EBS CSI\nElasticsearch"]:::master
                end

                subgraph SUB_PUB2 ["📦 dattran_subnet-1 / subnet_public_alb (AZ-b)"]
                    ALB_NOTE["(ALB spans both public subnets\nfor Multi-AZ availability)"]
                end
            end

            subgraph PRIV ["─── Private Subnet ───"]

                subgraph SUB_PRIV ["📦 dattran_private_subnet (AZ-a)"]
                    MASTER2["☸️  k8s_master_2\nt3.medium · 20 GB gp3\nIMDSv2 · IAM Profile\nHA Control Plane Join\nSSH via Nginx Bastion"]:::master
                    WORKER0["🖥️  k8s_worker-0\nt3.medium · 20 GB gp3\nIMDSv2 · IAM Profile\nWorker Join · NodePort :32222"]:::worker
                    WORKER1["🖥️  k8s_worker-1\nt3.medium · 20 GB gp3\nIMDSv2 · IAM Profile\nWorker Join · NodePort :32222"]:::worker
                    NFS["💾 k8s_nfs\nt3.small · 30 GB gp3\nNFS Server · PV/PVC\nSSH via Master Bastion"]:::nfs
                end
            end

        end

        subgraph SECURITY ["🔐 IAM · Security Groups · Key Pairs"]
            KP["🔑 aws_key_pair · k8s\nk8s.pem · All instances"]:::iam
            IAM["🛡️  IAM Instance Profile\nk8s_node_ebs_profile_1\nMasters + Workers + NFS"]:::iam
            SG["🔥 Security Groups\nk8s_nginx_lb\nk8s_master\nk8s_worker\nk8s_nfs"]:::sg
        end

    end

    %% ─── Traffic Flow ───────────────────────────────────────────────────
    INTERNET -->|"HTTP :80"| ALB
    ALB -->|"forward"| TG
    TG -->|"NodePort :32222"| WORKER0
    TG -->|"NodePort :32222"| WORKER1

    %% ─── Internal routing ───────────────────────────────────────────────
    NGINX -->|"TCP Proxy :6443\n(kubeapi)"| MASTER
    NGINX -->|"TCP Proxy :6443\n(kubeapi)"| MASTER2
    NGINX -.->|"Bastion SSH"| MASTER2
    NGINX -.->|"Bastion SSH"| WORKER0
    NGINX -.->|"Bastion SSH"| WORKER1
    NGINX -.->|"Bastion SSH"| NFS

    %% ─── K8s cluster internal ───────────────────────────────────────────
    MASTER -->|"cluster join"| MASTER2
    MASTER -->|"cluster join"| WORKER0
    MASTER -->|"cluster join"| WORKER1
    MASTER -.->|"NFS mounts PV/PVC"| NFS
```

---

## 2. draw.io XML (paste into app.diagrams.net — File → Import → XML)

Paste the content of `infrastructure-diagram.drawio` (in the same folder) into **Extras → Edit Diagram** on draw.io.

---

## 3. PlantUML (paste into plantuml.com or VS Code PlantUML extension)

```plantuml
@startuml K8s_AWS_Infrastructure
!define AWSPuml https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/v18.0/dist
!include AWSPuml/AWSCommon.puml
!include AWSPuml/NetworkingContentDelivery/ElasticLoadBalancing.puml
!include AWSPuml/Compute/EC2.puml
!include AWSPuml/Storage/SimpleStorageService.puml

skinparam rectangle {
    BackgroundColor #FAFAFA
    BorderColor #999
}
skinparam note {
    BackgroundColor #FFF9C4
}

title "K8s AWS Infrastructure — ap-southeast-1"

package "AWS ap-southeast-1" #E8F5E9 {

    package "VPC · dattran_vpc" #F1F8E9 {

        package "Public Subnets" #FFF3E0 {

            rectangle "dattran_subnet (AZ-a)" #FFECB3 {
                [k8s-main-alb\nALB · Internet-facing\nHTTP :80] as ALB #FF9900
                [k8s-tg-lb\nTarget Group\nHTTP→NodePort :32222] as TG #FFA726
                [k8s_nginx_lb\nt3.small · 10GB gp3\nNginx TCP Proxy\nFileBrowser · Bastion] as NGINX #00897B
                [k8s_master\nt3.medium · 50GB gp3\nkubeadm init\nRancher · ArgoCD\nPrometheus · Grafana\nHelm · EBS CSI] as MASTER #7B1FA2
            }

            rectangle "dattran_subnet-1 / subnet_public_alb (AZ-b)" #FFECB3 {
                note "ALB spans both AZs\nfor Multi-AZ HA" as AZ_NOTE
            }
        }

        package "Private Subnet" #E3F2FD {
            rectangle "dattran_private_subnet (AZ-a)" #BBDEFB {
                [k8s_master_2\nt3.medium · 20GB gp3\nHA Control Plane\nSSH via Bastion] as MASTER2 #6A1B9A
                [k8s_worker-0\nt3.medium · 20GB gp3\nWorker Node\nNodePort :32222] as W0 #1565C0
                [k8s_worker-1\nt3.medium · 20GB gp3\nWorker Node\nNodePort :32222] as W1 #1565C0
                [k8s_nfs\nt3.small · 30GB gp3\nNFS Server\nPV / PVC] as NFS #2E7D32
            }
        }
    }

    package "IAM · Security" #FFF8E1 {
        [aws_key_pair · k8s.pem] as KP
        [IAM Profile\nk8s_node_ebs_profile_1] as IAM
        [Security Groups\nnginx_lb · master\nworker · nfs] as SG #FFCDD2
    }
}

actor Internet

Internet -down-> ALB : "HTTP :80"
ALB -down-> TG : forward
TG -down-> W0 : ":32222"
TG -down-> W1 : ":32222"
NGINX -right-> MASTER : "TCP :6443"
NGINX -down-> MASTER2 : "TCP :6443 / Bastion"
NGINX ..> W0 : Bastion SSH
NGINX ..> W1 : Bastion SSH
NGINX ..> NFS : Bastion SSH
MASTER -down-> MASTER2 : kubeadm join
MASTER -down-> W0 : kubeadm join
MASTER -down-> W1 : kubeadm join
MASTER ..> NFS : NFS mount

@enduml
```
