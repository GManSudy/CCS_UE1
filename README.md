# MIS 2026 - Cloud Computing Security Projektarbeit

## Projektübersicht

Dieses Repository enthält die Terraform-Konfiguration für einen AWS EKS-Cluster sowie Kubernetes-Manifeste für eine sichere Cloud-Applikationsplattform. Das Projekt umfasst die Sicherheitsanalyse, Remediation und Härtung einer bestehenden EKS-Infrastruktur.

## Repository-Struktur

```
.
├── SECURITY_AUDIT.md                    # Detaillierter Security Audit Report
├── ccs-baseline-infrastructure-aws/     # Terraform Infrastructure Code
│   ├── main.tf                          # Provider und Backend Konfiguration
│   ├── variables.tf                     # Terraform Variables
│   ├── cluster.tf                       # EKS Cluster Definition
│   ├── cluster_node_group.tf            # EKS Worker Nodes
│   ├── cluster_nodes_user_data.tftpl    # Node Bootstrap Template
│   ├── network.tf                       # VPC, Subnets, NAT Gateway
│   ├── cloudtrail_logging.tf            # CloudTrail Audit Logging
│   └── container_registry.tf            # ECR Repository
├── kubernetes/                          # Kubernetes Manifeste (geplant)
│   ├── governance/                      # Policy Engine (Kyverno/OPA)
│   └── application/                     # Application Deployment
└── docs/                                # Zusätzliche Dokumentation (geplant)
```

## Projektstatus

### Aktuelle Phase: Security Audit und Remediation

**Stand:** 24. Februar 2026

### Abgeschlossen
- ✓ Initiale Code-Analyse
- ✓ Identifikation von 10 Sicherheitslücken (5 kritisch, 3 hoch, 2 mittel)
- ✓ Erstellung Security Audit Report mit Angriffsszenarien

### In Bearbeitung
- ⧗ Remediation der kritischen Sicherheitslücken
- ⧗ Terraform Code Hardening

### Ausstehend
- ☐ Encryption Layer Implementation (KMS, S3, CloudTrail)
- ☐ Kubernetes Policy Engine Deployment
- ☐ Secure Application Deployment
- ☐ End-to-End Testing

## Timeline

### Phase 1: Kritische Security Fixes (Tag 1)
**Ziel:** Elimination kritischer Angriffsvektoren  
**Aufwand:** 2-3 Stunden

#### Maßnahmen
1. IMDSv2 Enforcement
2. Entfernung SSH-Zugriff aus Internet
3. Migration Worker Nodes zu Private Subnets
4. Reduktion IAM-Berechtigungen (Entfernung RDS Full Access)
5. EKS API Public Access Hardening

**Deliverable:** Gehärtete Terraform-Konfiguration (Version 1.1)

---

### Phase 2: Encryption und Compliance (Tag 2)
**Ziel:** Data-at-Rest Encryption und Audit-Trail-Absicherung  
**Aufwand:** 3-4 Stunden

#### Maßnahmen
1. KMS Customer Managed Key Erstellung
2. S3 Bucket Encryption (CloudTrail Logs)
3. CloudTrail KMS Encryption
4. Terraform State Encryption und Versioning
5. ECR Image Scanning Aktivierung
6. ECR Tag Immutability

**Deliverable:** Vollständig verschlüsselte Infrastruktur (Version 1.2)

---

### Phase 3: Kubernetes Governance (Tag 3-4)
**Ziel:** Policy Enforcement für sichere Workloads  
**Aufwand:** 4-6 Stunden

#### Maßnahmen
1. Installation Policy Engine (Kyverno oder OPA Gatekeeper)
2. Policy-Definition für:
   - Mandatory Owner/Team Annotations
   - Security Context Requirements (non-root, read-only filesystem)
   - Resource Limits und Requests
   - ImagePullPolicy Always
   - Verbot privilegierter Container
3. Testing und Validation
4. Dokumentation Policy-Katalog

**Deliverable:** Kubernetes Security Policies

---

### Phase 4: Application Deployment (Tag 4-5)
**Ziel:** Deployment einer sicheren Multi-Service Applikation  
**Aufwand:** 4-6 Stunden

#### Anforderungen
- Mindestens 2 Services
- Integration eines AWS-Service (S3, RDS, DynamoDB)
- Secret Management via AWS Secrets Manager oder Parameter Store
- HTTP-Schnittstelle (externe Erreichbarkeit)
- Compliance mit Kubernetes Security Checklist
- IRSA (IAM Roles for Service Accounts) für AWS-Zugriff

#### Maßnahmen
1. Applikations-Design und Service-Architektur
2. Erstellung Kubernetes Manifests
   - Deployments mit Security Context
   - Services (ClusterIP, LoadBalancer/Ingress)
   - NetworkPolicies
   - ServiceAccounts mit IRSA
   - ConfigMaps und Secret-Referenzen
3. AWS-Integration Setup (z.B. S3 Bucket, Parameter Store)
4. Deployment und Functional Testing

**Deliverable:** Funktionierende, abgesicherte Applikation

---

### Phase 5: Testing und Validation (Tag 5)
**Ziel:** End-to-End Security Validation  
**Aufwand:** 2-3 Stunden

#### Maßnahmen
1. Security Scanning
   - `kube-bench` (CIS Benchmark)
   - `kube-hunter` (Penetration Testing)
   - `trivy` (Vulnerability Scanning)
2. Policy Enforcement Tests
3. AWS Security Hub Review
4. Funktionale Tests der Applikation
5. Dokumentations-Review

**Deliverable:** Test-Report und finale Dokumentation

---

## Quick Start

### Voraussetzungen
```bash
# Required Tools
- Terraform >= 1.14.3
- AWS CLI v2
- kubectl >= 1.30
- Helm >= 3.x (für Policy Engine)

# AWS Credentials
aws sts get-caller-identity
```

### Infrastructure Deployment

```bash
# 1. Repository clonen
cd /home/atlas/CCS_UE1/ccs-baseline-infrastructure-aws

# 2. Terraform Backend initialisieren
terraform init

# 3. Änderungen reviewen
terraform plan

# 4. Infrastruktur deployen
terraform apply

# 5. Kubeconfig aktualisieren
aws eks update-kubeconfig --region eu-central-1 --name ccs-infra-eks-cluster

# 6. Cluster-Zugriff verifizieren
kubectl get nodes
```

### Nach Phase 1 (Security Hardening)

```bash
# Terraform re-apply nach Code-Änderungen
cd ccs-baseline-infrastructure-aws
terraform plan -out=tfplan
terraform apply tfplan

# Verifizierung
kubectl get nodes
kubectl describe node <node-name> | grep -i metadata
```

## Sicherheitslücken - Executive Summary

Die initiale Analyse identifizierte folgende kritische Schwachstellen:

| ID | Beschreibung | Schweregrad | CVSS | Status |
|----|--------------|-------------|------|--------|
| 1.1 | SSH-Zugriff aus Internet (0.0.0.0/0) | Kritisch | 9.8 | Offen |
| 1.2 | Worker Nodes in Public Subnets | Kritisch | 8.6 | Offen |
| 1.3 | IMDSv1 aktiviert (SSRF-Risiko) | Kritisch | 8.8 | Offen |
| 1.4 | AmazonRDSFullAccess auf Worker Nodes | Kritisch | 8.5 | Offen |
| 1.5 | EKS API Public Access | Kritisch | 7.5 | Offen |
| 1.6 | S3 Bucket ohne Encryption | Hoch | 6.5 | Offen |
| 1.7 | CloudTrail ohne KMS Encryption | Hoch | 6.5 | Offen |
| 1.8 | ECR ohne Image Scanning | Mittel | 5.3 | Offen |
| 1.9 | ECR ohne Tag Immutability | Mittel | 4.3 | Offen |
| 1.10 | Terraform State ohne Encryption | Hoch | 6.5 | Offen |

**Detaillierte Analyse:** Siehe [SECURITY_AUDIT.md](SECURITY_AUDIT.md)

## Compliance und Standards

Das Projekt orientiert sich an folgenden Security Standards:

- **CIS AWS Foundations Benchmark v1.5**
- **CIS Kubernetes Benchmark v1.8**
- **Kubernetes Pod Security Standards (Restricted)**
- **AWS EKS Best Practices Guide**
- **OWASP Kubernetes Security Cheat Sheet**

## Verwendete Technologien

### Infrastructure as Code
- Terraform 1.14.3
- AWS Provider 6.28.0

### AWS Services
- Amazon EKS 1.34
- Amazon VPC (Public/Private Subnets, NAT Gateway)
- Amazon ECR
- AWS CloudTrail
- AWS KMS (geplant)
- AWS Systems Manager (Session Manager)
- AWS Secrets Manager / Parameter Store (geplant)

### Kubernetes Ecosystem
- Kubernetes 1.34
- Kyverno oder OPA Gatekeeper (Policy Engine)
- AWS Load Balancer Controller (geplant)
- ExternalDNS (optional)
- Cert-Manager (optional)

### Security Tools (Validation)
- kube-bench (CIS Compliance)
- kube-hunter (Penetration Testing)
- Trivy (Vulnerability Scanning)
- Checkov (IaC Security)
- Falco (Runtime Security - optional)

## Kontakt und Support

**Projekt:** MIS 2026 Cloud Computing Security  
**Institution:** [Hochschule/Universität]  
**Semester:** Sommersemester 2026

## Lizenz und Hinweise

Dieses Repository dient ausschließlich Bildungszwecken im Rahmen der MIS 2026 Projektarbeit.

**Wichtige Hinweise:**
- Die Terraform-Konfiguration deployed reale AWS-Ressourcen, die Kosten verursachen
- Nach Abschluss des Projekts sollten alle Ressourcen via `terraform destroy` entfernt werden
- Sensitive Daten (Credentials, API-Keys) dürfen nicht in das Repository committed werden
- AWS Secrets und Credentials sind in `.gitignore` eingetragen

## Nächste Schritte

1. Review des [SECURITY_AUDIT.md](SECURITY_AUDIT.md)
2. Beginn mit Phase 1: Kritische Security Fixes
3. Iteratives Testing nach jeder Phase
4. Dokumentation der Implementierungsentscheidungen
5. Vorbereitung Abgabegespräch

---

**Letzte Aktualisierung:** 24. Februar 2026  
**Version:** 1.0  
**Status:** Security Audit abgeschlossen, Remediation ausstehend
