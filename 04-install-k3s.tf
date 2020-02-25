data "template_file" "k3s_install_script" {
    count = length(var.server_topology)
    template = file("templates/install_k3s.sh")
    vars = {
        pod_cidr = cidrsubnet(var.private_ip_cidr, 5, 31 - count.index)
        service_cidr = cidrsubnet(var.private_ip_cidr, 5, count.index)
        hostname = element(var.server_topology.*.hostname, count.index)
        k3s_version = var.k3s_version
        helm_version = var.helm_version
    }
}

resource "null_resource" "install_k3s"{
    count = length(var.server_topology)
    depends_on = [
        data.template_file.k3s_install_script,
        packet_device.k3s_nodes
    ]
    
    connection {
        type = "ssh"
        user = "root"
        private_key = file(var.ssh_key_path)
        host = element(packet_device.k3s_nodes.*.access_public_ipv4, count.index)
    }

    provisioner "file" {
        content = element(data.template_file.k3s_install_script.*.rendered, count.index)
        destination = "/root/install_k3s.sh"
    }

    provisioner "remote-exec" {
        inline = ["bash /root/install_k3s.sh"]
    }
}
