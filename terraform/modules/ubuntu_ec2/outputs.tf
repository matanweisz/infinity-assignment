output "instance_id" {
  description = "ID of the Ubuntu EC2 instance"
  value       = aws_instance.ubuntu.id
}

output "public_ip" {
  description = "Public IP of the Ubuntu EC2 instance"
  value       = aws_instance.ubuntu.public_ip
}
