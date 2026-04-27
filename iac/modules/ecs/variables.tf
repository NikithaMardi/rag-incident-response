variable "ecs_cluster_name"{
    type = string
}

variable "task_definition"{
    type = object({
      family = string
      name = string
      image = string
      cpu = number
      memory = number
      containerPort = number
      hostPort = number
      volume_name = string
      efs_file_system_id = string
      volume_containerPath = string
    })
}

variable "vpc_id"{
    type = string
}

variable "ecs_service"{
    type = string 
    default = "rag_incident_response_service"
}

variable "aws_alb"{
    type = object({
      subnets = list(string)
      name = string
    })
}

variable "secretsmanager_secret"{
    type = string
}

variable "log_group"{
    type = string
}

variable "alb_tg"{
    type = string
}