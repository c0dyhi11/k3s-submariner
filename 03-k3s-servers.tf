resource "packet_device" "k3s_nodes" {
    count = length(var.server_topology)
    hostname = element(var.server_topology.*.hostname, count.index)
    plan = element(var.server_topology.*.plan, count.index)
    facilities = [element(var.server_topology.*.facilty, count.index)]
    operating_system = var.operating_system
    billing_cycle = var.billing_cycle
    project_id = packet_project.new_project.id
}

resource "packet_bgp_session" "bgp_session" {
    count = length(var.server_topology)
    device_id = element(packet_device.k3s_nodes.*.id, count.index)
    address_family = "ipv4"
}
