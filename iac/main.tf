resource "aws_secretsmanager_secret" "secret" {
  name = "grok-api-key"
}

module "efs" {
    source = "./modules/efs"
    efs_creation_token = "rag_incident_response_efs"
    efs_mount_target = {
      "az-1a" = "",
      "az-1b" = ""
    }
    vpc_id = ""
    efs_sg = {
      from_port = 2049
      to_port = 2049
      protocol = "NFS"
      cidr_blocks = [""]
    }
}

module "ecs" {
    source = "./modules/ecs"
    ecs_cluster_name = "rag_incident_response_cluster"
    task_definition = {
      family = "rag_incident_response"
      name = "rag_incident_response"
      image = "string"
      cpu = 4000
      memory = 2000
      containerPort = 8000
      hostPort = 8000
      volume_name = "chroma_db_rag"
      efs_file_system_id = module.efs.efs_filesystem_id
      volume_containerPath = "./chroma_db"
    }
    vpc_id = ""
    ecs_service = "rag_incident_response_service"
    aws_alb = {
      subnets = [""]
      name = "rag_incident_response_alb"
    }
    secretsmanager_secret = aws_secretsmanager_secret.secret.arn
    log_group = "rag_incident_response_log"
    alb_tg = "rag_incident_response_tg"
}