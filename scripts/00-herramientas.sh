#!/usr/bin/env bash
# Instala eksctl y kubectl en ~/bin si no estan (CloudShell no trae eksctl)
set -euo pipefail

mkdir -p "$HOME/bin"
export PATH="$HOME/bin:$PATH"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
esac
SO="$(uname -s | tr '[:upper:]' '[:lower:]')"

if ! command -v eksctl >/dev/null; then
  echo "-> instalando eksctl"
  curl -sSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_${ARCH}.tar.gz" \
    | tar -xz -C "$HOME/bin"
fi

if ! command -v kubectl >/dev/null; then
  echo "-> instalando kubectl"
  VERSION="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
  curl -sSL -o "$HOME/bin/kubectl" "https://dl.k8s.io/release/${VERSION}/bin/${SO}/${ARCH}/kubectl"
  chmod +x "$HOME/bin/kubectl"
fi

for h in aws eksctl kubectl jq; do
  command -v "$h" >/dev/null || { echo "falta $h"; exit 1; }
done

echo "eksctl  $(eksctl version)"
echo "kubectl $(kubectl version --client -o json | jq -r .clientVersion.gitVersion)"
