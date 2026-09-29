# rj-devsecops-edge-lab

A security-hardened, cloud-native **edge telemetry service** and its full
DevSecOps delivery pipeline — the reference project I point to as a
DevSecOps / Platform engineer. It demonstrates the whole loop from IoT/edge
device-to-cloud data through secure CI/CD and infrastructure-as-code, not just
a single component.

> **What this repo proves:** I own security *and* developer platforms
> end-to-end — a hardened container, least-privilege Kubernetes workload,
> GCP+Azure infrastructure-as-code in Terraform, and a CI pipeline that runs
> unit tests, lint, SAST, dependency scan, secret scan, IaC static analysis,
> manifest validation, and container scanning before anything ships.

---

## Repository map

| Path | Purpose |
|------|---------|
| `app/` | Python (FastAPI) edge telemetry service: `/healthz`, `/readyz`, `/metrics`, `POST /telemetry` |
| `Dockerfile` | Non-root, read-only-rootfs, multi-stage hardened image |
| `k8s/` | Kubernetes manifests: namespace, deployment (hardened `securityContext`), service, NetworkPolicy (default-deny), HPA |
| `terraform/` | Terraform: GKE cluster + kubernetes workload as code (GCP path); `chunks/aks.tf` (Azure/AKS variant) |
| `.github/workflows/devsecops.yml` | Secure CI/CD: test, lint, SAST, SCA, secret scan, tf validate + Checkov, kubeconform, build+trivy+push GHCR |

## The service (`app/`)

A minimal HTTP API that receives sensor/edge telemetry ("device-to-cloud"). It
represents the data plane of an IIoT deployment in this reference repo.

```bash
# local run
cd app && pip install -r requirements-dev.txt && uvicorn main:app --reload
# test
cd app && pytest -v
```

Endpoints: `GET /healthz`, `GET /readyz`, `GET /metrics`, `POST /telemetry`.

## Hardened container

The `Dockerfile` uses a multi-stage build and a runtime with:

- **Non-root user** (`appuser`, uid 10001), no-home, no-login-shell
- **Read-only root filesystem** is set at Kubernetes level
- Pinned base image + pinned pip deps (see `Requirements`)
- `HEALTHCHECK` against `/healthz`

## Kubernetes hardening (`k8s/`)

The deployment applies defense-in-depth:

- `runAsNonRoot: true`, `runAsUser/Group: 10001`
- `allowPrivilegeEscalation: false`, drop `ALL` capabilities
- `readOnlyRootFilesystem: true`
- seccomp `RuntimeDefault`
- resource requests/limits (no runaway CPU/mem)
- liveness + readiness probes
- **NetworkPolicy default-deny** then allow same-namespace HTTP
- HPA 2→8 replicas on CPU

```bash
kubectl apply -k k8s/   # or: kubectl apply -f k8s/
```

## Infrastructure as code (`terraform/`)

GCP-first, Azure variant included.

```bash
cd terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

Provision: `google_container_cluster.rj-edge` (private-ish standard GKE) plus
the kubernetes workload (namespace, deployment, service, HPA) as code.
The `kubernetes` provider reads an injected kubeconfig in CI/ops
(`TF_VAR_kubeconfig`), keeping `terraform validate` credential-free locally.

## Secure CI/CD (`.github/workflows/devsecops.yml`)

Nine jobs that gate every PR/push to `main`:

1. **test** — pytest
2. **lint** — ruff
3. **sast** — Bandit (`-ll`)
4. **dependency-scan** — pip-audit
5. **secret-scan** — Gitleaks
6. **terraform** — `fmt -check` + `validate` + **Checkov** (IaC static analysis)
7. **k8s-manifests** — **kubeconform** strict validation
8. **docker** — buildx multi-arch build, **Trivy** container scan (SARIF → CodeQL),
   push to GHCR, tag leaf sha + `latest`

The secure path is the easy path: everything a healthy release needs runs on
every push, and findings land in GitHub Security via SARIF upload.

---

## Notes & honesty

- Image push target deviates from the classic managed-GKE story in one
  practical way: images land in **GHCR** (`ghcr.io/rijalllllllll/rj-edge-telemetry`)
  because it needs no external registry credentials on push. For a GCP shop you
  would push to Artifact Registry with Workload Identity — the IaC already
  provisions the cluster for that model.
- **Kubernetes orchestration at scale / multi-cluster** and **production
  GCP/Azure** are actively being built toward; this repo is the verifiable,
  deployable artifact of that learning rather than a claim of years of
  commercial platform operation.

## License

MIT — see `LICENSE`.