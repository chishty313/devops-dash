variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-qtec-devops"
}

variable "vm_name" {
  description = "Name of the Linux virtual machine"
  type        = string
  default     = "vm-qtec-devops"
}

variable "vm_size" {
  description = "Azure VM SKU (Standard_B2s = 2 vCPU / 4 GB RAM)"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Linux admin username (used for SSH and cloud-init)"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key content (e.g. contents of ~/.ssh/id_rsa.pub)"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to reach port 22. Use your IP (e.g. '203.0.113.5/32') or '*' for open."
  type        = string
  default     = "*"
}

variable "repo_url" {
  description = "GitHub repo HTTPS URL to clone on first boot (e.g. https://github.com/you/qtec-devops-engineer.git)"
  type        = string
}
