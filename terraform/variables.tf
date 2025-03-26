variable "resource_prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "bastion_ssh_port" {
  description = "Port for inbound SSH connections to bastion"
  type = string
  default = 2222
}

#####################
# VISIT MANAGER SQL #
#####################

variable "visit_manager_postgres_version" {
  description = "Major version od PostgreSQL to be used in visit manager service"
  type = string
  default = "16"
}

variable "visit_manager_postgres_db_name" {
  description = "Name of PostgreSQL DB for visit manager service"
  type = string
  default = "visit_manager"
}

variable "visit_manager_postgres_port" {
  description = "Port for connections to DB for visit manager service"
  type = string
  default = "5432"
}

variable "visit_manager_postgres_root_user" {
  description = "Root username for visit manager PostgreSQL"
  type = string
  default = "root"
}

variable "visit_manager_postgres_root_password" {
  description = "Root user passoword for visit manager PostgreSQL. A random password will be generated if not provided."
  type = string
  default = null
}

variable "visit_manager_postgres_user" {
  description = "User username for visit manager PostgreSQL"
  type = string
  default = "user"
}

variable "visit_manager_postgres_user_password" {
  description = "User passowrd for visit manager PostgreSQL. A random password will be generated if not provided."
  type = string
  default = null
}
