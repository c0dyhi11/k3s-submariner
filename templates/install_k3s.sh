#!/bin/bash
cd ~

CLUSTER_CIDR='${pod_cidr}'
SERVICE_CIDR='${service_cidr}'
K3S_VER='${k3s_version}'
HELM_VER='${helm_version}'
CLUSTER_NAME='${cluster_name}'
MASTER_NODE_IP='${master_node_ip}'
WORKER_NODE_IP='${worker_node_ip}'
SSH_PRIVATE_KEY='${ssh_private_key}'
GLOBAL_IP='${global_ip}'
GLOBAL_NETMASK='${global_netmask}'
GLOBAL_CIDR='${global_cidr}'
BGP_PASSWORD='${bgp_password}'
BPG_ASN='${bgp_asn}'
echo "write Private Key to file"
cat <<EOF >/root/.ssh/id_rsa
$SSH_PRIVATE_KEY
EOF
chmod 0400 /root/.ssh/id_rsa

echo "Set SSH config to not do StrictHostKeyChecking"
cat <<EOF >/root/.ssh/config
Host *
    StrictHostKeyChecking no
EOF
chmod 0400 /root/.ssh/config

echo "Install k3s without Traefik"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VER INSTALL_K3S_EXEC="server --no-deploy traefik --cluster-cidr $CLUSTER_CIDR --service-cidr $SERVICE_CIDR --cluster-domain $CLUSTER_NAME.local" sh -

echo "Wait for k3s token to exist"
until [ -f /var/lib/rancher/k3s/server/node-token ]; do sleep 1; done
echo "Wait until the kubeconfig is generated"
until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 1; done

echo "Gather token and install k3s on worker node via SSH"
TOKEN=`cat /var/lib/rancher/k3s/server/node-token`
URL="https://$MASTER_NODE_IP:6443"
ssh root@$WORKER_NODE_IP <<-SSH
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$k3s_ver K3S_URL=$URL K3S_TOKEN=$TOKEN sh -
    apt-get update -y
    apt-get install bird -y
    cat <<-EOS >> /etc/network/interfaces

auto lo:0
iface lo:0 inet static
    address $GLOBAL_IP
    netmask $GLOBAL_NETMASK
EOS

    mv /etc/bird/bird.conf /etc/bird/bird.conf.old
    cat <<-EOF >> /etc/bird/bird.conf
filter packet_bgp {
    if net = $GLOBAL_IP/$GLOBAL_CIDR then accept;
}
router id __PRIVATE_IPV4_ADDRESS__;
protocol direct {
    interface "lo";
}
protocol kernel {
    scan time 10;
    persist;
    import all;
    export all;
}
protocol device {
    scan time 10;
}
protocol bgp {
    export filter packet_bgp;
    local as $BPG_ASN;
    neighbor __GATEWAY_IP__ as 65530;
    password "$BGP_PASSWORD"; 
}
EOF
SSH
ssh root@$WORKER_NODE_IP <<-'SSH'
    HOST_ID=`curl https://metadata.packet.net/2009-04-04/meta-data/instance-id`
    AUTH_TOKEN='${auth_token}'
    curl -X POST -H "X-Auth-Token: $AUTH_TOKEN" https://api.packet.net/devices/$HOST_ID/bgp/sessions?address_family=ipv4
    IP_ADDRESS=`ip -4 a show dev bond0 | grep 'inet 10'| awk '{print $2}' | awk -F'/' '{print $1}'`
    GATEWAY=`ip route | grep $IP_ADDRESS | awk -F'/' '{print $1}'`
    sed -i "s/__PRIVATE_IPV4_ADDRESS__/$IP_ADDRESS/g" /etc/bird/bird.conf
    sed -i "s/__GATEWAY_IP__/$GATEWAY/g" /etc/bird/bird.conf
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p
    ifup lo:0
    systemctl restart bird
SSH

echo "Install helm"
curl -LO https://get.helm.sh/helm-$HELM_VER-linux-amd64.tar.gz
tar -xf helm-$HELM_VER-linux-amd64.tar.gz 
mv linux-amd64/helm /usr/local/bin/
rm -rf linux-amd64 helm-$HELM_VER-linux-amd64.tar.gz

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
