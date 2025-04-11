variable "resource_prefix" {
  description = "Prefix for all resources"
  type        = string
}

###########
# Bastion #
###########

variable "bastion_ssh_port" {
  description = "Port for inbound SSH connections to bastion"
  type        = string
  default     = 2222
}

variable "bastion_instance_size" {
  description = "Instance size of bastion machine"
  type        = string
  default     = "e2-micro"
}

#####################
# VISIT MANAGER SQL #
#####################

variable "visit_manager_postgres_instance_size" {
  description = "Postgres instance size"
  type        = string
  default     = "db-custom-1-3840"
}

variable "visit_manager_postgres_version" {
  description = "Major version od PostgreSQL to be used in visit manager service"
  type        = string
  default     = "16"
}

variable "visit_manager_postgres_db_name" {
  description = "Name of PostgreSQL DB for visit manager service"
  type        = string
  default     = "visit_manager"
}

variable "visit_manager_postgres_port" {
  description = "Port for connections to DB for visit manager service"
  type        = string
  default     = "5432"
}

variable "visit_manager_postgres_root_user" {
  description = "Root username for visit manager PostgreSQL"
  type        = string
  default     = "root"
}

variable "visit_manager_postgres_root_password" {
  description = "Root user passoword for visit manager PostgreSQL. A random password will be generated if not provided."
  type        = string
  default     = null
}

variable "visit_manager_postgres_user" {
  description = "User username for visit manager PostgreSQL"
  type        = string
  default     = "user"
}

variable "visit_manager_postgres_user_password" {
  description = "User passowrd for visit manager PostgreSQL. A random password will be generated if not provided."
  type        = string
  default     = null
}

#######
# GKE #
#######

variable "gke_min_nodes" {
  description = "Minimum number of nodes in GKE CLUSTER"
  type        = number
  default     = 1
}

variable "gke_initial_nodes" {
  description = "Initial number of nodes in GKE CLUSTER"
  type        = number
  default     = 1
}

variable "gke_max_nodes" {
  description = "Maximum number of nodes in GKE CLUSTER"
  type        = number
  default     = 2
}

variable "gke_instance_size" {
  description = "Instance size of nodes in GKE CLUSTER"
  type        = string
  default     = "e2-medium"
}

#################
# ElasticSearch #
#################

variable "elasticsearch_instance_size" {
  description = "Instance size of ES machine"
  type        = string
  # 2 vCPUs, 8 GB memory
  default = "e2-standard-2"
}

#########
# Kafka #
#########

variable "kafka_vpcu_count" {
  description = "Number of vCPUs in Kafka cluster"
  type        = number
  # min value
  default = 3
}

variable "kafka_memory_bytes" {
  description = "Memory size in Kafka cluster"
  type        = number
  # min value
  default = 3221225472
}
