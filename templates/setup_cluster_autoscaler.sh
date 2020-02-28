#!/bin/bash
MASTER_IP='${master_ip}'
API_PORT='${api_port}'
CLUSTER_CIDR='${pod_cidr}'
SERVICE_CIDR='${service_cidr}'
K3S_VER='${k3s_version}'
CLUSTER_NAME='${cluster_name}'
POOL_NAME='${pool_name}'
MIN_NODES=${min_nodes}
MAX_NODES=${max_nodes}

TOKEN=`cat /var/lib/rancher/k3s/server/node-token`
URL="https://$MASTER_IP:$API_PORT"
K3S_SCRIPT=$(cat <<EOF
#!/bin/bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VER K3S_URL=$URL K3S_TOKEN=$TOKEN sh -
EOF
)
USER_DATA=$(printf "$K3S_SCRIPT" | base64 -w 0)
sed -i "s/__USER_DATA__/$USER_DATA/g" /root/autoscaler/cluster_autoscaler_secret.yaml

kubectl apply -f /root/autoscaler
