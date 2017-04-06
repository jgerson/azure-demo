variable "name" {
  type        = "string"
  description = "The prefix to add to virtual machine resources"
}

variable "location" {
  type        = "string"
  description = "The location for the Virtual Network"
}

variable "vms_per_cluster" {
  type        = "string"
  description = "The number of VMs to create in each region"
}

variable "resource_group_name" {
  type        = "string"
  description = "The name of the resource group in which to create the virtual network"
}

variable "node_name" {
  type        = "list"
  description = "The name(s) to use to identify each Consul node within the Consul cluster"
}

variable "public_nic" {
  type        = "list"
  description = "The IDs of the Network Interfaces with Public IPs"
}

variable "public_ip" {
  type        = "list"
  description = "The Public IP(s) created"
}

variable "public_fqdn" {
  type        = "list"
  description = "The Public FQDN(s) associated with the Public IP(s) created"
}

variable "storage_account" {
  type        = "string"
  description = "The Storage Account to use to place VHD storage containers for each VM"
}

variable "container_name" {
  type        = "string"
  description = "The name of the Storage Container in which to store VHDs"
}

variable "env_tag" {
  type        = "string"
  description = "The cluster name to tag resources with"
}
