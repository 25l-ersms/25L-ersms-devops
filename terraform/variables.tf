variable "resource_prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "bastion_ssh_port" {
  description = "Port for inbound SSH connections to bastion"
  type = string
  default = 2222
}
