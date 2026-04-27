resource "aws_secretsmanager_secret" "secret" {
  name = "grok-api-key"
}

module "efs" {
    source = "./modules/efs"
    efs_creation_token = "rag_incident_response_efs"
    efs_mount_target = {
      "az-1a" = "subnet-013288bd75f998917",
      "az-1b" = "subnet-04f535866dc872c2b",
      "az-1c" = "subnet-08bb0ea67654c316f"
    }
    vpc_id = "vpc-03bb14e7802d3b540"
    efs_sg = [{
      from_port = 2049
      to_port = 2049
      protocol = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }]
}

module "ecs" {
    source = "./modules/ecs"
    ecs_cluster_name = "rag_incident_response_cluster"
    task_definition = {
      family = "rag_incident_response"
      name = "rag_incident_response"
      image = "572670265443.dkr.ecr.us-east-1.amazonaws.com/rag_incident_response:latest"
      cpu = 512
      memory = 1024
      containerPort = 8000
      hostPort = 8000
      volume_name = "chroma_db_rag"
      efs_file_system_id = module.efs.efs_filesystem_id
      volume_containerPath = "./chroma_db"
    }
    vpc_id = "vpc-03bb14e7802d3b540"
    ecs_service = "rag_incident_response_service"
    aws_alb = {
      subnets = ["subnet-013288bd75f998917","subnet-08bb0ea67654c316f","subnet-04f535866dc872c2b"]
      name = "rag-incident-response-alb"
    }
    secretsmanager_secret = aws_secretsmanager_secret.secret.arn
    log_group = "/ecs/rag-incident-response"
    alb_tg = "rag-incident-response-tg"
}