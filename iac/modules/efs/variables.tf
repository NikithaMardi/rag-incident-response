variable "efs_creation_token"{
    type = string
}

variable "efs_mount_target"{
    type = map(string)
}

variable "efs_sg"{
    type = list(object({
      from_port = number
      to_port = number
      protocol = string
      cidr_blocks = list(string)
    }))
}

variable "vpc_id"{
    type = string
}
