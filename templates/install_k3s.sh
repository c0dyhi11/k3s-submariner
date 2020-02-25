#!/bin/bash
cd ~

CLUSTER_CIDR='${pod_cidr}'
SERVICE_CIDR='${service_cidr}'
K3S_VER='${k3s_version}'
HELM_VER='${helm_version}'
HOSTNAME='${hostname}'

echo "Install k3s without Traefik"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VER INSTALL_K3S_EXEC="server --no-deploy traefik --cluster-cidr $CLUSTER_CIDR --service-cidr $SERVICE_CIDR --cluster-domain $HOSTNAME.local" sh

echo "Install helm"
curl -LO https://get.helm.sh/helm-$HELM_VER-linux-amd64.tar.gz
tar -xf helm-$HELM_VER-linux-amd64.tar.gz 
mv linux-amd64/helm /usr/local/bin/
rm -rf linux-amd64 helm-$HELM_VER-linux-amd64.tar.gz

echo "Wait until the kubeconfig is generated"
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do sleep 1; done

echo "Copy the kube config to the 'Known' location for things like helm"
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

echo "Add the stable repo to helm"
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update

echo 'Install ingress controller "ingress-nginx"'
cat <<EOF > ~/nginx-ingress-values.yaml
controller:
    kind: DaemonSet
    hostNetwork: true
    service:
        type: ClusterIP
rbac:
    create: true
EOF
NGINX_NAMESPACE="ingress-nginx"
kubectl create namespace $NGINX_NAMESPACE
helm install ingress-nginx stable/nginx-ingress --namespace $NGINX_NAMESPACE -f ~/nginx-ingress-values.yaml
