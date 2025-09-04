Do not commit real secrets here. Create secrets out-of-band or use an encrypted workflow (Sealed Secrets or SOPS).

Grafana admin (example, unencrypted):

- Create via kubectl (recommended for manual bootstrap):

  kubectl -n monitoring create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password='<STRONG_PASSWORD>'

- Or use a manifest template (do not commit real values): see grafana-admin-secret.example.yaml

For GitOps with encryption, prefer:
- Bitnami Sealed Secrets (encrypt Secret, commit SealedSecret), or
- Mozilla SOPS + Argo CD plugin (commit encrypted file).

