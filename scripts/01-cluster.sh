#!/usr/bin/env bash
# Cluster de EKS con 2 nodos. Tarda ~15-20 minutos.
set -euo pipefail
source "$(dirname "$0")/config.sh"

paso "cluster $CLUSTER"

if aws eks describe-cluster --name "$CLUSTER" >/dev/null 2>&1; then
  echo "ya existe"
else
  CONFIG="$(mktemp)"
  cat > "$CONFIG" <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER}
  region: ${AWS_REGION}
availabilityZones: [${ZONAS//,/, }]
iam:
  serviceRoleARN: ${LAB_ROLE_ARN}
  withOIDC: false
managedNodeGroups:
  - name: workers
    instanceType: ${NODO_TIPO}
    desiredCapacity: ${NODOS}
    minSize: ${NODOS}
    maxSize: ${NODOS}
    volumeSize: 20
    iam:
      instanceRoleARN: ${LAB_ROLE_ARN}
EOF
  eksctl create cluster -f "$CONFIG"
  rm -f "$CONFIG"
fi

paso "kubeconfig"
aws eks update-kubeconfig --name "$CLUSTER" --region "$AWS_REGION"

paso "nodos"
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl get nodes -o wide
