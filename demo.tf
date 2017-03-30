/*
configure the Microsoft Azure provider

assumes the following environment vars are set:
    ARM_SUBSCRIPTION_ID
    ARM_CLIENT_ID
    ARM_CLIENT_SECRET
    ARM_TENANT_ID
*/
provider "azurerm" {}

variable "atlas_token" {
  type = "string"
}

variable "atlas_environment" {
  type    = "string"
  default = "demo_dc"
}

variable "location" {
  type = "list"

  default = ["West US", "West US 2"]
}

variable "vms_per_region" {
  type    = "string"
  default = 3
}

# create a resource group 
resource "azurerm_resource_group" "Demo" {
  name     = "2AzureDemo"
  location = "West US"
}

# create virtual network(s)
resource "azurerm_virtual_network" "DemoVN" {
  count               = "${length(var.location)}"
  name                = "DemoVN-${count.index}"
  address_space       = ["10.0.0.0/16"]
  location            = "${element(var.location, count.index)}"
  resource_group_name = "${azurerm_resource_group.Demo.name}"
}

# create subnet(s)
resource "azurerm_subnet" "DemoSubnet" {
  count                = "${length(var.location)}"
  name                 = "DemoSubnet-${count.index}"
  resource_group_name  = "${azurerm_resource_group.Demo.name}"
  virtual_network_name = "${element(azurerm_virtual_network.DemoVN.*.name, count.index)}"
  address_prefix       = "10.0.2.0/24"
}

# create public IP(s)
resource "azurerm_public_ip" "DemoPublicIP" {
  count                        = "${length(var.location) * var.vms_per_region}"
  name                         = "DemoPublicIP-${count.index}"
  location                     = "${element(var.location, count.index)}"
  resource_group_name          = "${azurerm_resource_group.Demo.name}"
  public_ip_address_allocation = "dynamic"

  #https://github.com/hashicorp/terraform/issues/6634#issuecomment-222843191
  domain_name_label = "${format("azure-demo%02d-%.8s",count.index,  uuid())}"

  tags {
    environment = "Demo"
  }
}

# create network interface(s)
resource "azurerm_network_interface" "DemoNIC" {
  count               = "${length(var.location) * var.vms_per_region}"
  name                = "DemoNIC-${count.index}"
  location            = "${element(var.location, count.index)}"
  resource_group_name = "${azurerm_resource_group.Demo.name}"

  ip_configuration {
    name                          = "IPConfig-${count.index}"
    subnet_id                     = "${element(azurerm_subnet.DemoSubnet.*.id, count.index)}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.DemoPublicIP.*.id, count.index)}"
  }
}

# create storage account
resource "azurerm_storage_account" "DemoSA" {
  count               = "${length(var.location)}"
  name                = "2azuredemosa${count.index}"
  resource_group_name = "${azurerm_resource_group.Demo.name}"
  location            = "${element(var.location, count.index)}"
  account_type        = "Standard_LRS"

  tags {
    environment = "Demo"
  }
}

# create storage container
resource "azurerm_storage_container" "DemoSC" {
  count                 = "${length(var.location)}"
  name                  = "vhd"
  resource_group_name   = "${azurerm_resource_group.Demo.name}"
  storage_account_name  = "${element(azurerm_storage_account.DemoSA.*.name, count.index)}"
  container_access_type = "private"
  depends_on            = ["azurerm_storage_account.DemoSA"]
}

# create virtual machine(s)
resource "azurerm_virtual_machine" "DemoVM" {
  count                 = "${length(var.location) * var.vms_per_region}"
  name                  = "DemoVM-${count.index}"
  location              = "${element(var.location, count.index)}"
  resource_group_name   = "${azurerm_resource_group.Demo.name}"
  network_interface_ids = ["${element(azurerm_network_interface.DemoNIC.*.id, count.index)}"]
  vm_size               = "Standard_A0"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name          = "myosdisk"
    vhd_uri       = "${element(azurerm_storage_account.DemoSA.*.primary_blob_endpoint, count.index)}${element(azurerm_storage_container.DemoSC.*.name, count.index)}/myosdisk-${count.index}.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags {
    environment = "Demo"
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "set -x",
      "sudo apt-get update && sudo apt-get install -y curl unzip",
      "sudo mkdir -p /opt/consul/data",
      "cd /opt/consul",
      "sudo curl -O https://releases.hashicorp.com/consul/0.7.5/consul_0.7.5_linux_amd64.zip",
      "sudo unzip consul_0.7.5_linux_amd64.zip",
      "sudo chmod 755 consul",
      "cd /opt/consul",
      "sudo nohup ./consul agent -server -bind 0.0.0.0 -client 0.0.0.0 -datacenter dc-\"${count.index%length(var.location)}\" -data-dir=\"/opt/consul/data\" -bootstrap-expect 3 -atlas=\"${var.atlas_environment}\" -atlas-join -atlas-token=\"${var.atlas_token}\" &",
      "sleep 1",
    ]

    connection {
      host     = "${element(azurerm_public_ip.DemoPublicIP.*.fqdn, count.index)}"
      type     = "ssh"
      user     = "testadmin"
      password = "Password1234!"
    }
  }
}
