variable "environment" {
   description = "Name of this environment"
   default = "production"
}

variable "aws_access_key" {
    description = "Access key for AWS"
}

variable "aws_secret_key" {
    description = "Secret key for AWS"
}

variable "aws_region" {
    description = "Region where we will operate."
    default = "eu-west-1"
}

variable "aws_availability_zones" {
    type = "map"
    description = "Map of region to availability zone"
    default {
        "us-east-1"      = ""
        "us-west-2"      = ""
        "us-west-1"      = ""
        "eu-west-1"      = "eu-west-1a,eu-west-1b,eu-west-1c"
        "eu-central-1"   = ""
        "ap-southeast-1" = ""
        "ap-northeast-1" = ""
        "ap-southeast-2" = ""
        "ap-northeast-2" = ""
        "sa-east-1"      = ""
    }
}

variable "aws_availability_zone_count" {
  description = "The number of availability zones we require"
  default     = "3"
}

variable "bastion_ami" {
  description = "The ami to use for the bastion instance"
  default = "ami-464af835"
}

variable "bastion_user" {
  description = "The user to use to log in to the bastion instance"
  default = "ubuntu"
}

variable "bastion_instance_type" {
  description = "The instance type for bastion hosts"
  default = "t2.micro"
}

variable "ssh_public_key" {
    description = "Contents of an SSH public key to grant access to created instances"
}
