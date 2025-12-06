output "bastion_public_ip" {
  description = "Public IP address of the bastion EC2 instance"
  value       = aws_instance.bastion.public_ip
}

output "natgw_eip" {
  description = "Public IP address of the NAT gateway"
  value       = aws_eip.natgw.public_ip
}

output "bastion_private_ip" {
  description = "Private IP address of the bastion EC2 instance"
  value       = aws_instance.bastion.private_ip
}

output "control_plane_private_ip" {
  description = "Private IP address of the control plane node"
  value       = aws_instance.control_plane.private_ip
}

output "worker_private_ips" {
  description = "Private IP addresses of the worker nodes"
  value       = aws_instance.worker[*].private_ip
}

output "burstable_worker_private_ips" {
  description = "Private IP addresses of burstable worker nodes"
  value       = aws_instance.burstable_worker[*].private_ip
}