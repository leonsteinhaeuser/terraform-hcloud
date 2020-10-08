##################################################
#                                                #
# server definition for worker and master nodes  #
#                                                #
##################################################

resource "hcloud_server" "k8s_nodes_master" {
  count       = var.hetzner_master_count
  name        = format("%s-%d", var.hetzner_master_machine_prefix, count.index + 1)
  server_type = var.hetzner_master_machine_type
  image       = var.hetzner_machine_operation_system
  datacenter  = var.hetzner_datacenter
  backups     = var.hetzner_machine_master_backups
  ssh_keys    = [hcloud_ssh_key.k8s_admin.id]
  labels      = {
    machine_type=var.hetzner_machine_label_type_master, 
    network_name=var.hetzner_machine_label_type_private_network
  }

  connection {
    host        = self.ipv4_address
    user        = var.ssh_username
    type        = "ssh"
    private_key = file(var.ssh_private_key)
  }

  provisioner "file" {
    source      = "scripts/install.sh"
    destination = "/root/install.sh"
  }

  provisioner "remote-exec" {
    inline = ["bash /root/install.sh"]
  }

  provisioner "file" {
    source = "scripts/init-cluster.sh"
    destination = "/root/init-cluster.sh"
  }

  # provision cluster
  provisioner "remote-exec" {
    inline = ["bash /root/init-cluster.sh ${var.k8s_network_ip_range} ${var.k8s_network_ip_service_subnet_range} ${var.k8s_external_kubernetes_address}"]
  }

  # copy provision token from kubernetes cluster
  provisioner "local-exec" {
    command = "bash scripts/lcl-copy-kubeadm-token.sh"

    environment = {
      SSH_PRIVATE_KEY = var.ssh_private_key
      SSH_USERNAME = var.ssh_username
      SSH_HOST = hcloud_server.k8s_nodes_master[0].ipv4_address
      TARGET = ".secrets/kubeadm_join/"
    }
  }

  provisioner "file" {
    source = ".secrets/kubeadm_join"
    destination = "/root/kubeadm_join"
  }

  provisioner "file" {
    source = "scripts/provision-at-cluster.sh"
    destination = "/root/provision-at-cluster.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash /root/provision-at-cluster.sh ${var.hetzner_master_machine_prefix}",
    ]
  }
}


resource "hcloud_server" "k8s_nodes_worker" {
  count       = var.hetzner_worker_count
  name        = format("%s-%d", var.hetzner_worker_machine_prefix, count.index + 1)
  server_type = var.hetzner_worker_machine_type
  image       = var.hetzner_machine_operation_system
  datacenter  = var.hetzner_datacenter
  backups     = var.hetzner_machine_worker_backups
  ssh_keys    = [hcloud_ssh_key.k8s_admin.id]
  depends_on  = [hcloud_server.k8s_nodes_master]
  labels      = {
    machine_type=var.hetzner_machine_label_type_worker, 
    network_name=var.hetzner_machine_label_type_private_network
  }

  connection {
    host        = self.ipv4_address
    user        = var.ssh_username
    type        = "ssh"
    private_key = file(var.ssh_private_key)
  }

  provisioner "file" {
    source      = "scripts/install.sh"
    destination = "/root/install.sh"
  }

#  provisioner "file" {
#    source = "configs/kubeadm.conf"
#    destination = "/root/kubeadm.conf"
#  }

  provisioner "remote-exec" {
    inline = ["bash /root/install.sh"]
  }

  provisioner "file" {
    source = ".secrets/kubeadm_join"
    destination = "/root/kubeadm_join"
  }

  provisioner "file" {
    source = "scripts/provision-at-cluster.sh"
    destination = "/root/provision-at-cluster.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash /root/provision-at-cluster.sh ${var.hetzner_master_machine_prefix}",
    ]
  }
}

resource "hcloud_server_network" "master_node_network" {
  count = var.hetzner_master_count
  server_id = hcloud_server.k8s_nodes_master[count.index].id
  subnet_id = hcloud_network_subnet.master.id
}

resource "hcloud_server_network" "worker_node_network" {
  count = var.hetzner_worker_count
  server_id = hcloud_server.k8s_nodes_worker[count.index].id
  subnet_id = hcloud_network_subnet.master.id
}
