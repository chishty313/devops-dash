output "resource_group_name" {
  description = "Azure resource group that contains all provisioned resources"
  value       = azurerm_resource_group.rg.name
}

output "vm_public_ip" {
  description = "Public IP address of the VM — point your DNS A record here"
  value       = azurerm_public_ip.pip.ip_address
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "next_steps" {
  description = "Post-provision checklist"
  value       = <<-EOT
    1. Add DNS A record:  qtec.chishty.me -> ${azurerm_public_ip.pip.ip_address}
    2. Wait ~2 min for cloud-init to finish, then SSH:
         ssh ${var.admin_username}@${azurerm_public_ip.pip.ip_address}
    3. On the VM, create /opt/qtec/.env from .env.example and fill in MONGODB_URI.
    4. Set GitHub secrets: SSH_PRIVATE_KEY, SERVER_IP, SERVER_USER.
    5. Push to main branch — the CI/CD pipeline will deploy automatically.
  EOT
}
