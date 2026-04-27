resource "aws_efs_file_system" "rag_incident_efs" {
  creation_token = var.efs_creation_token

}

resource "aws_efs_mount_target" "efs_mount_target" {
  for_each = var.efs_mount_target
  file_system_id = aws_efs_file_system.rag_incident_efs.id
  subnet_id      = each.value
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_security_group" "efs_sg" {
  name        = "efs_sg"
  description = "efs sg for ecs"
  vpc_id      = var.vpc_id
  dynamic "ingress" {
    for_each = var.efs_sg
    content{
            from_port        = ingress.value.from_port
            to_port          = ingress.value.to_port
            protocol         = ingress.value.protocol
            cidr_blocks      = ingress.value.cidr_blocks
            }
        }
  tags = {
    Name = "efs_sg"
  }
}
