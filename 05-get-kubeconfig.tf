resource "null_resource" "copy_kubeconfigs"{
    depends_on = [null_resource.install_k3s]
    count = length(var.server_topology)
    provisioner "local-exec" {
        command = <<-EOC
            mkdir -p ./kubeconfigs; 
            scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${element(packet_device.k3s_nodes.*.access_public_ipv4, count.index)}:/etc/rancher/k3s/k3s.yaml ./kubeconfigs/${element(packet_device.k3s_nodes.*.hostname, count.index)}
            sed -i 's/127.0.0.1/${element(packet_device.k3s_nodes.*.access_public_ipv4, count.index)}/g' kubeconfigs/${element(packet_device.k3s_nodes.*.hostname, count.index)}
        EOC
    }
    provisioner "local-exec" {
        when = destroy
        command = <<-EOD
            rm -rf ./kubeconfigs
        EOD
    }
}

resource "null_resource" "install_submariner_broker"{
    depends_on = [null_resource.copy_kubeconfigs]
    provisioner "local-exec" {
        command = <<-EOC
            subctl deploy-broker --kubeconfig kubeconfigs/${packet_device.k3s_nodes.0.hostname} --no-dataplane
        EOC
    }
}

resource "null_resource" "join_submariner_nodes"{
    depends_on = [null_resource.copy_kubeconfigs]
    count = length(var.server_topology)
    provisioner "local-exec" {
        command = <<-EOC
            kubectl --kubeconfig kubeconfigs/${element(packet_device.k3s_nodes.*.hostname, count.index)} label node ${element(packet_device.k3s_nodes.*.hostname, count.index)} submariner.io/gateway=true
            subctl join --kubeconfig kubeconfigs/${element(packet_device.k3s_nodes.*.hostname, count.index)} broker-info.subm --disable-nat --servicecidr=${cidrsubnet(var.private_ip_cidr, 5, count.index)} --clusterid ${element(packet_device.k3s_nodes.*.hostname, count.index)} --clustercidr=${cidrsubnet(var.private_ip_cidr, 5, 31 - count.index)}
        EOC
    }
    provisioner "local-exec" {
        when = destroy
        command = <<-EOD
            rm -f broker-info.subm
        EOD
    }
}
