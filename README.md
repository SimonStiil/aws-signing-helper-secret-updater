# AWS Signing Helper Secret Updater

This project provides a containerized, Kubernetes-ready solution that retrieves secrets from AWS using the `aws_signing_helper` and updates them in Kubernetes using an embedded version of [`go-file-secret-sync`](https://github.com/SimonStiil/go-file-secret-sync).

The service is designed to act as a bridge: it first fetches credentials or secrets from AWS Roles Anywhere via the signing helper, then securely pushes those secrets into Kubernetes as resources—automating the flow of external secrets into your cluster.

## Overview

The container in this project combines two key components:
- **AWS Signing Helper**: Used to authenticate and fetch secrets/credentials from AWS Roles Anywhere using X.509 certificates.
- **go-file-secret-sync (embedded)**: Used to push the retrieved secrets directly into Kubernetes as Secrets, ConfigMaps, or other supported resources.

This enables Kubernetes workloads to easily access AWS-managed secrets with seamless rotation and AWS IAM integration.

## Features

- **All-in-one Container**: Runs both the AWS signing helper and go-file-secret-sync utility.
- **Automatic Secret Sync**: Retrieves secrets from AWS and updates them in Kubernetes.
- **Kubernetes Native**: Includes manifests for deployment, service, configmap, and certificate resources.
- **Configurable via Environment**: All AWS and sync settings are controlled with environment variables.
- **Secure By Design**: Leverages cert-manager and AWS Roles Anywhere for identity, and stores secrets in Kubernetes.

## Prerequisites

- Kubernetes cluster (v1.20+ recommended)
- cert-manager installed and configured
- AWS IAM Roles Anywhere set up with:
  - Trust Anchor
  - Profile
  - IAM Role

## Deployment

Manifests for deploying this solution are provided in the [`/deployment`](./deployment) directory of the repository.

### 1. Configure cert-manager Issuer

Ensure you have a `ClusterIssuer` or `Issuer` configured for cert-manager. Example:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  selfSigned: {}
```

### 2. Update ConfigMap

Edit `deployment/configmap.yaml` (or the relevant ConfigMap) with your AWS ARNs and any secret sync configuration:

```yaml
data:
  TRUST_ANCHOR_ARN: "arn:aws:rolesanywhere:...:trust-anchor/..."
  PROFILE_ARN: "arn:aws:rolesanywhere:...:profile/..."
  ROLE_ARN: "arn:aws:iam::...:role/..."
  # Additional go-file-secret-sync config goes here
```

### 3. Deploy Resources

Apply the manifests using Kustomize or `kubectl`:

```sh
kubectl apply -k deployment/
```

This will create:

- A Certificate resource (managed by cert-manager)
- A Secret containing the certificate and key
- A ConfigMap with AWS ARNs and sync settings
- A Deployment running the combined updater
- A Service if needed

### 4. How It Works

- The pod authenticates to AWS using the provided certificates and ARNs.
- It retrieves the desired secret(s) using `aws_signing_helper`.
- The embedded `go-file-secret-sync` then pushes the secret into Kubernetes.

## Environment Variables

The container expects the following environment variables:

IAM Roles Anywhere:
- `CERTIFICATE`: Path to the certificate file (e.g., `/etc/certs/tls.crt`)
- `PRIVATE_KEY`: Path to the private key file (e.g., `/etc/certs/tls.key`)
- `TRUST_ANCHOR_ARN`: AWS Roles Anywhere Trust Anchor ARN
- `PROFILE_ARN`: AWS Roles Anywhere Profile ARN
- `ROLE_ARN`: IAM Role ARN to assume
go-file-secret-sync:
- `FOLDER_TO_READ`: Path to the file to watch/read. (e.g. `/home/user/.aws`)
- `SECRET_TO_WRITE`: Name of the Kubernetes Secret to create/update.

All variables are set via the deployment manifest and configmap.

## Security Considerations

- Certificates and keys are mounted from Kubernetes secrets managed by cert-manager.
- Restrict pod/service access using Kubernetes network policies.
- Ensure only necessary permissions are granted to the IAM Role used.

## References

- [AWS IAM Roles Anywhere for Kubernetes](https://github.com/aws-samples/aws-iam-ra-for-kubernetes)
- [AWS Roles Anywhere Credential Helper](https://docs.aws.amazon.com/rolesanywhere/latest/userguide/credential-helper.html)
- [cert-manager](https://cert-manager.io/)
- [go-file-secret-sync](https://github.com/SimonStiil/go-file-secret-sync)

---

*This project is for demonstration and prototyping purposes. Review and adapt for production use.*