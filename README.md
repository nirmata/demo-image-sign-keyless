# Demo: Keyless Image Validation with Kyverno

This repo builds a container image and requests a signature from the **nirmata-central-workflow** repo. Kyverno on a Kind cluster validates image signatures using an image verification policy.

## Setup

- **demo-image-sign-keyless** (this repo): Builds the image, pushes to GHCR, and triggers the central signing repo via `repository_dispatch`.
- **nirmata-central-workflow**: Signs the image using Cosign keyless (Fulcio + Rekor).
- **Kyverno**: Deployed on a Kind cluster; validates Pod images with a `verifyImages` ClusterPolicy.

## Demo Steps

### 1. Trigger build and sign

```bash
git tag v1.0.8    #tag should be in the format v*
git push origin v1.0.8
```

### 2. Verify build and sign

- Check that the GitHub Action for **this repo** (build + push) completed successfully.
- Check that the **nirmata-central-workflow** repo’s “Sign Nirmata image” workflow ran and succeeded (confirm image is signed).

### 3. Configure Kyverno for the registry

Details [here](https://kyverno.io/docs/policy-types/cluster-policy/verify-images/sigstore/#authentication).



### 4. Deploy the policy

Apply the ClusterPolicy that verifies keyless signatures for `ghcr.io/nirmata/*`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
    - name: check-image-signature
      match:
        any:
        - resources:
            kinds:
              - Pod
      verifyImages:
      - imageReferences:
        - "ghcr.io/nirmata/*"
        attestors:
        - entries:
          - keyless:
              subject: "https://github.com/nirmata/nirmata-central-workflow/.github/workflows/sign-image.yml@refs*"
              issuer: "https://token.actions.githubusercontent.com"
              rekor:
                  url: https://rekor.sigstore.dev
                  ignoreTlog: true
```

Save as `policy.yaml` and run:

```bash
kubectl apply -f policy.yaml
```

### 5. Positive test (signed image)

```bash
kubectl run pod --image=ghcr.io/nirmata/demo-image-sign-keyless:v1.0.8
```

The pod should be allowed (policy passes).

### 6. Negative test (unsigned image)

```bash
kubectl run pod --image=ghcr.io/nirmata/kubectl:1.35.0
```

The pod should be blocked by Kyverno (image not signed by the expected keyless workflow).
