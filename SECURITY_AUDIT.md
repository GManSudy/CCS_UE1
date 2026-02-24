# Security Audit Report - EKS Terraform Infrastructure

**Projekt:** CCS Cloud Infrastructure Migration  
**Datum:** 24. Februar 2026  
**Audit-Typ:** Infrastructure as Code Security Review  
**Scope:** AWS EKS Cluster Terraform Configuration  
**Geprüfte Komponenten:** Terraform v1.14.3, AWS Provider v6.28.0

---

## Executive Summary

Die vorliegende Terraform-Konfiguration für die AWS EKS-Infrastruktur weist mehrere kritische Sicherheitslücken auf, die das Risiko einer Kompromittierung der Cluster-Infrastruktur erheblich erhöhen. Die Analyse identifizierte 10 Sicherheitsprobleme unterschiedlicher Schweregrade, von denen 5 als kritisch eingestuft werden.

Die dokumentierten Schwachstellen ermöglichen potenzielle Angriffsszenarien wie:
- Unbefugter Zugriff auf Worker Nodes via SSH aus dem Internet
- Credential Theft durch SSRF-Angriffe gegen IMDSv1
- Lateral Movement durch übermäßige IAM-Berechtigungen
- Direkte Exposition der Kubernetes API gegenüber dem Internet

Eine sofortige Remediation wird empfohlen, bevor die Infrastruktur in Produktion geht.

---

## 1. Identifizierte Sicherheitslücken

### 1.1 SSH-Zugriff aus dem Internet (KRITISCH)

**Schweregrad:** Kritisch  
**CVSS Score:** 9.8 (Critical)  
**Betroffene Datei:** `cluster_node_group.tf` (Zeilen 28-34)  
**CWE:** CWE-284 (Improper Access Control)

#### Technische Details
```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

Die Security Group `eks-worker-node-sg` erlaubt SSH-Verbindungen (Port 22) von beliebigen IP-Adressen (`0.0.0.0/0`).

#### Angriffsszenario
Ein Angreifer kann systematisch SSH-Brute-Force-Angriffe gegen die Worker Nodes durchführen. Bei erfolgreicher Kompromittierung eines Nodes erhält der Angreifer:
- Direkten Zugriff auf die Node-Instanz
- Möglichkeit zur Eskalation auf Kubernetes-Ebene
- Zugriff auf alle auf dem Node laufenden Container und deren Secrets
- Potenzielle Lateral Movement-Möglichkeiten innerhalb des Clusters

#### Remediation
Entfernung der SSH-Ingress-Regel. Zugriff auf Nodes sollte ausschließlich über AWS Systems Manager Session Manager erfolgen (bereits durch `AmazonSSMManagedInstanceCore`-Policy ermöglicht).

---

### 1.2 Worker Nodes in Public Subnets (KRITISCH)

**Schweregrad:** Kritisch  
**CVSS Score:** 8.6 (High)  
**Betroffene Datei:** `cluster_node_group.tf` (Zeile 102)  
**CWE:** CWE-668 (Exposure of Resource to Wrong Sphere)

#### Technische Details
```hcl
subnet_ids = [aws_subnet.public_subnet[0].id]
```

Die EKS Worker Nodes werden in Public Subnets mit `map_public_ip_on_launch = true` deployt, wodurch sie öffentliche IP-Adressen erhalten.

#### Angriffsszenario
Worker Nodes mit öffentlichen IP-Adressen sind direkt aus dem Internet erreichbar. Dies erweitert die Angriffsfläche erheblich:
- Direkte Netzwerk-Scans können die Nodes identifizieren
- Jeder exponierte Service auf den Nodes ist angreifbar
- DDoS-Angriffe können direkt gegen die Nodes gerichtet werden
- Die Kombination mit der SSH-Schwachstelle (1.1) potenziert das Risiko

#### Remediation
Migration der Worker Nodes in Private Subnets. Outbound-Konnektivität bleibt über NAT Gateway gewährleistet.

---

### 1.3 IMDSv1 aktiviert (KRITISCH)

**Schweregrad:** Kritisch  
**CVSS Score:** 8.8 (High)  
**Betroffene Datei:** `cluster_node_group.tf` (Zeilen 62-65)  
**CWE:** CWE-522 (Insufficiently Protected Credentials)

#### Technische Details
```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "optional"
  http_put_response_hop_limit = 1
}
```

Die Instance Metadata Service Version 1 (IMDSv1) ist aktiviert (`http_tokens = "optional"`).

#### Angriffsszenario
IMDSv1 ist anfällig für Server-Side Request Forgery (SSRF) Angriffe:
1. Ein Angreifer identifiziert eine SSRF-Schwachstelle in einer im Cluster laufenden Applikation
2. Über SSRF-Anfragen an `http://169.254.169.254/latest/meta-data/iam/security-credentials/` werden temporäre IAM-Credentials der Node-IAM-Role extrahiert
3. Mit diesen Credentials erhält der Angreifer die vollen Berechtigungen der Worker Node Role (inkl. RDS Full Access)
4. Der Angreifer kann sämtliche RDS-Datenbanken im Account kompromittieren

#### Remediation
Erzwingung von IMDSv2 durch Setzen von `http_tokens = "required"`. IMDSv2 erfordert Session-basierte Requests, die SSRF-Angriffe effektiv verhindern.

---

### 1.4 Übermäßige IAM-Berechtigungen (KRITISCH)

**Schweregrad:** Kritisch  
**CVSS Score:** 8.5 (High)  
**Betroffene Datei:** `cluster_node_group.tf` (Zeile 19)  
**CWE:** CWE-269 (Improper Privilege Management)

#### Technische Details
```hcl
"arn:aws:iam::aws:policy/AmazonRDSFullAccess",
```

Die Worker Node IAM Role besitzt die AWS-Managed Policy `AmazonRDSFullAccess`.

#### Angriffsszenario
Das Prinzip der geringsten Rechte (Principle of Least Privilege) wird verletzt:
- Jeder im Cluster laufende Pod kann via Service Account die Node-IAM-Credentials nutzen (sofern IRSA nicht konfiguriert ist)
- Ein kompromittierter Pod oder Container erhält vollständigen Zugriff auf alle RDS-Instanzen:
  - Löschen von Datenbanken
  - Modification von DB-Konfigurationen
  - Erstellen von öffentlich zugänglichen Snapshots
  - Credential-Exfiltration aus RDS
- Bei Kombination mit IMDSv1-Schwachstelle (1.3) wird das Angriffsszenario trivial

#### Remediation
Entfernung der `AmazonRDSFullAccess`-Policy. Falls RDS-Zugriff erforderlich ist, sollte dieser über IAM Roles for Service Accounts (IRSA) mit minimalen, applikationsspezifischen Berechtigungen implementiert werden.

---

### 1.5 EKS API Public Access (KRITISCH)

**Schweregrad:** Kritisch  
**CVSS Score:** 7.5 (High)  
**Betroffene Datei:** `cluster.tf` (Zeile 26)  
**CWE:** CWE-284 (Improper Access Control)

#### Technische Details
```hcl
vpc_config {
  subnet_ids              = aws_subnet.private_subnet[*].id
  endpoint_private_access = true
  endpoint_public_access  = true
}
```

Der Kubernetes API Server Endpoint ist sowohl privat als auch öffentlich zugänglich.

#### Angriffsszenario
Die Kubernetes API ist aus dem Internet erreichbar:
- Angreifer können die API auf Schwachstellen scannen
- Brute-Force-Angriffe gegen API-Credentials sind möglich
- Bei Kompromittierung von API-Credentials (z.B. durch Phishing oder gestohlene kubeconfig) kann der Cluster vollständig übernommen werden
- Selbst bei aktivierter Authentifizierung erhöht die öffentliche Exposition das Risiko von Zero-Day-Exploits

#### Remediation
Deaktivierung des Public Access (`endpoint_public_access = false`). Administrative Zugriffe sollten über VPN, AWS Client VPN oder Bastion Hosts erfolgen. Für CI/CD-Systeme können spezifische IP-Whitelists über `public_access_cidrs` konfiguriert werden.

---

### 1.6 S3 Bucket ohne Encryption

**Schweregrad:** Hoch  
**CVSS Score:** 6.5 (Medium)  
**Betroffene Datei:** `cloudtrail_logging.tf`  
**CWE:** CWE-311 (Missing Encryption of Sensitive Data)

#### Technische Details
Der S3 Bucket für CloudTrail-Logs besitzt keine explizite Encryption-at-Rest Konfiguration.

#### Angriffsszenario
CloudTrail-Logs enthalten sensitive Informationen über alle API-Aktivitäten:
- IAM-Principal-Informationen
- IP-Adressen von API-Calls
- Resource-Identifikatoren
- Fehlerhafte Zugriffsversuche

Bei unbefugtem Zugriff auf den S3 Bucket können diese Informationen für Reconnaissance genutzt werden.

#### Remediation
Aktivierung von S3 Default Encryption mit AWS KMS (SSE-KMS) für erweiterte Zugriffskontrolle und Audit-Fähigkeiten.

---

### 1.7 CloudTrail ohne KMS Encryption

**Schweregrad:** Hoch  
**CVSS Score:** 6.5 (Medium)  
**Betroffene Datei:** `cloudtrail_logging.tf`  
**CWE:** CWE-311 (Missing Encryption of Sensitive Data)

#### Technische Details
CloudTrail ist konfiguriert, jedoch ohne dedizierte KMS-Key-Verschlüsselung.

#### Remediation
Konfiguration eines dedizierten KMS Customer Managed Key für CloudTrail mit restriktiver Key Policy.

---

### 1.8 ECR ohne Image Scanning

**Schweregrad:** Mittel  
**CVSS Score:** 5.3 (Medium)  
**Betroffene Datei:** `container_registry.tf`  
**CWE:** CWE-1104 (Use of Unmaintained Third Party Components)

#### Technische Details
Das ECR Repository hat keine Image Scanning-Konfiguration.

#### Angriffsszenario
Container Images können bekannte Schwachstellen (CVEs) enthalten, die unentdeckt bleiben und zur Kompromittierung von Pods führen können.

#### Remediation
Aktivierung von `scan_on_push = true` für automatisches Vulnerability Scanning.

---

### 1.9 ECR ohne Tag Immutability

**Schweregrad:** Mittel  
**CVSS Score:** 4.3 (Medium)  
**Betroffene Datei:** `container_registry.tf`  
**CWE:** CWE-345 (Insufficient Verification of Data Authenticity)

#### Technische Details
Image Tags im ECR Repository sind mutable.

#### Angriffsszenario
Ein Angreifer mit ECR-Schreibrechten könnte ein kompromittiertes Image unter einem bereits verwendeten Tag hochladen, wodurch laufende Workloads bei Neustart das manipulierte Image verwenden.

#### Remediation
Aktivierung von `image_tag_mutability = "IMMUTABLE"`.

---

### 1.10 Terraform State ohne Server-Side Encryption

**Schweregrad:** Hoch  
**CVSS Score:** 6.5 (Medium)  
**Betroffene Datei:** `main.tf`  
**CWE:** CWE-311 (Missing Encryption of Sensitive Data)

#### Technische Details
Der S3 Backend für Terraform State hat keine explizite Encryption-Konfiguration.

#### Angriffsszenario
Der Terraform State enthält hochsensible Informationen:
- Resource IDs und ARNs
- Potentiell Secrets und Passwörter (bei unsachgemäßer Verwendung)
- Infrastruktur-Details für Reconnaissance

#### Remediation
Konfiguration von `encrypt = true` im S3 Backend und Aktivierung von Versioning für State-Recovery.

---

## 2. Remediation-Plan und Timeline

### Phase 1: Kritische Fixes (Tag 1)
**Priorität:** Highest  
**Geschätzter Aufwand:** 2-3 Stunden

#### Aufgaben:
1. **IMDSv2 Enforcement** (30 Min)
   - Änderung `http_tokens = "required"` in `cluster_node_group.tf`
   - Test: Verifizierung via `curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/`

2. **Removal of SSH Ingress Rule** (15 Min)
   - Entfernung des SSH-Ingress-Blocks aus Security Group
   - Dokumentation: SSM Session Manager als Alternative

3. **Worker Nodes to Private Subnets** (45 Min)
   - Änderung `subnet_ids` zu `aws_subnet.private_subnet[*].id`
   - Test: Verifizierung der Node-Konnektivität via kubectl

4. **Removal of RDS Full Access Policy** (15 Min)
   - Entfernung der `AmazonRDSFullAccess`-Policy aus IAM Role
   - Dokumentation: IRSA-Implementierung für zukünftige Applikationen

5. **Disable EKS Public API Access** (30 Min)
   - Setzen `endpoint_public_access = false`
   - Alternativ: Konfiguration von `public_access_cidrs` mit spezifischen IP-Ranges
   - Test: Verifizierung von kubectl-Zugriff via VPN/Bastion

6. **Terraform Apply** (30 Min)
   - `terraform plan` Review
   - `terraform apply` mit Node Group Recreation

### Phase 2: Encryption und Compliance (Tag 2)
**Priorität:** High  
**Geschätzter Aufwand:** 3-4 Stunden

#### Aufgaben:
1. **KMS Key Creation** (45 Min)
   - Erstellung eines KMS Customer Managed Key
   - Key Policy mit Least Privilege
   - Aliase: `cloudtrail-encryption`, `s3-encryption`

2. **CloudTrail S3 Bucket Encryption** (30 Min)
   - Aktivierung von S3 SSE-KMS
   - Bucket Policy Update für KMS-Key-Zugriff

3. **CloudTrail KMS Encryption** (30 Min)
   - Konfiguration `kms_key_id` in CloudTrail Resource
   - CloudTrail Service Principal in KMS Key Policy

4. **Terraform State Encryption** (30 Min)
   - Hinzufügung von `encrypt = true` im S3 Backend
   - S3 Bucket Versioning Aktivierung
   - State Lock via DynamoDB

5. **ECR Image Scanning** (15 Min)
   - Aktivierung von `scan_on_push = true`
   - Konfiguration von Enhanced Scanning (optional)

6. **ECR Tag Immutability** (15 Min)
   - Setzen `image_tag_mutability = "IMMUTABLE"`

7. **Terraform Apply** (45 Min)
   - State Migration Test
   - Vollständiges Deployment

### Phase 3: Kubernetes Security (Tag 3-5)
**Priorität:** High  
**Geschätzter Aufwand:** 8-12 Stunden

#### Aufgaben:
1. **Policy Engine Deployment** (3-4 Stunden)
   - Installation von Kyverno oder OPA Gatekeeper
   - Policy Definition für:
     - Mandatory Owner/Team Annotations
     - Security Context Requirements
     - Resource Limits Enforcement
     - ImagePullPolicy Requirements
     - Non-root Container Enforcement

2. **Application Deployment** (4-6 Stunden)
   - Secure Manifest Creation nach Kubernetes Security Checklist
   - Security Context Configuration
   - NetworkPolicy Definition
   - IRSA Setup für AWS Service Access
   - Secret Management via AWS Secrets Manager/Parameter Store
   - Ingress/LoadBalancer Configuration

3. **Testing und Validation** (2-3 Stunden)
   - Policy Enforcement Tests
   - Application Functionality Tests
   - Security Scanning (kube-bench, kube-hunter)
   - Penetration Testing

---

## 3. Best Practices und Referenzen

### AWS Security Best Practices
- **EKS Best Practices Guide:** https://aws.github.io/aws-eks-best-practices/security/docs/
- **AWS Security Hub Controls:** Aktivierung für kontinuierliche Compliance-Überwachung
- **AWS GuardDuty:** Aktivierung für EKS Runtime Monitoring

### Kubernetes Security Standards
- **Pod Security Standards:** Implementation via Pod Security Admission
- **CIS Kubernetes Benchmark:** Regelmäßige Scans via kube-bench
- **Network Segmentation:** Implementierung von NetworkPolicies für Zero-Trust

### Compliance Frameworks
- **CIS AWS Foundations Benchmark**
- **NIST Cybersecurity Framework**
- **ISO 27001 Controls**

---

## 4. Monitoring und Continuous Security

### Empfohlene Security Tools
1. **Falco:** Runtime Security Monitoring für Kubernetes
2. **Trivy:** Vulnerability Scanning für Container und IaC
3. **Checkov:** Static Analysis für Terraform Code
4. **kube-bench:** CIS Benchmark Compliance Check
5. **Polaris:** Kubernetes Configuration Validation

### Audit und Logging
- **CloudTrail:** Aktiviert für API-Audit
- **EKS Control Plane Logging:** Aktivierung aller Log-Types
- **FluentBit/FluentD:** Centralized Logging Solution
- **Prometheus + Grafana:** Metrics und Alerting

---

## 5. Risiko-Bewertung

### Vor Remediation
- **Gesamtrisiko:** Kritisch
- **Wahrscheinlichkeit erfolgreicher Kompromittierung:** Hoch
- **Potentieller Schaden:** Vollständige Cluster-Kompromittierung, Datenverlust, Compliance-Verstöße

### Nach Remediation
- **Gesamtrisiko:** Niedrig-Mittel
- **Wahrscheinlichkeit erfolgreicher Kompromittierung:** Niedrig
- **Potentieller Schaden:** Minimiert durch Defense-in-Depth

---

## 6. Anhang

### A. Terraform Validation Commands
```bash
# Static Analysis
checkov -d . --framework terraform

# Format Check
terraform fmt -check -recursive

# Validation
terraform validate

# Security Scan
tfsec .
```

### B. Post-Deployment Verification
```bash
# Node Verification
kubectl get nodes
kubectl describe node <node-name> | grep -A5 "metadata"

# Security Group Verification
aws ec2 describe-security-groups --group-ids <sg-id>

# IMDSv2 Verification (auf Node via SSM)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/

# ECR Scan Results
aws ecr describe-image-scan-findings --repository-name <repo-name> --image-id imageTag=<tag>
```

### C.責任者 (Responsibility Matrix)

| Schwachstelle | Remediation Owner | Validation Owner | Deadline |
|---------------|-------------------|------------------|----------|
| 1.1 - SSH Public | Platform Team | Security Team | Tag 1 |
| 1.2 - Public Subnets | Platform Team | Security Team | Tag 1 |
| 1.3 - IMDSv1 | Platform Team | Security Team | Tag 1 |
| 1.4 - IAM Permissions | Platform Team | IAM Team | Tag 1 |
| 1.5 - Public API | Platform Team | Security Team | Tag 1 |
| 1.6 - S3 Encryption | Platform Team | Compliance Team | Tag 2 |
| 1.7 - CloudTrail KMS | Platform Team | Compliance Team | Tag 2 |
| 1.8 - ECR Scanning | Platform Team | Security Team | Tag 2 |
| 1.9 - ECR Immutability | Platform Team | Security Team | Tag 2 |
| 1.10 - State Encryption | Platform Team | Platform Team | Tag 2 |

---

**Dokumentversion:** 1.0  
**Letzte Aktualisierung:** 24. Februar 2026  
**Nächstes Review:** Nach Phase 2-Abschluss
