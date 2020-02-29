resource "null_resource" "install_submariner_broker"{
    depends_on = [
        null_resource.copy_kubeconfigs
    ]
    provisioner "local-exec" {
        command = <<-EOC
            subctl deploy-broker --kubeconfig kubeconfigs/${var.server_topology.0.cluster_name} --no-dataplane
        EOC
    }
}

resource "null_resource" "join_submariner_nodes"{
    depends_on = [
        null_resource.install_submariner_broker
    ]
    count = length(var.server_topology)
    provisioner "local-exec" {
        command = <<-EOC
            kubectl --kubeconfig kubeconfigs/${element(var.server_topology.*.cluster_name, count.index)} label node ${element(packet_device.k3s_master_nodes.*.hostname, count.index)} submariner.io/gateway=true
            subctl join --kubeconfig kubeconfigs/${element(var.server_topology.*.cluster_name, count.index)} broker-info.subm --disable-nat --servicecidr=${cidrsubnet(var.private_ip_cidr, 5, count.index)} --clusterid ${element(packet_device.k3s_master_nodes.*.hostname, count.index)} --clustercidr=${cidrsubnet(var.private_ip_cidr, 5, 31 - count.index)}
        EOC
    }
    provisioner "local-exec" {
        when = destroy
        command = <<-EOD
            rm -f broker-info.subm
        EOD
    }
}
