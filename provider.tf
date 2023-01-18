terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  backend "s3" {
    bucket = "knm-delete-me"
    key    = "terraform-state"
    region = "us-east-1"
  }
  required_version = ">= 1.2.0"
}


provider "aws" {
  region                   = "us-east-1"
  profile                  = "demo_acc"
  //shared_config_files      = ["%USERPROFILE%\\.aws\\config"]
  //shared_credentials_files = ["%USERPROFILE%\\.aws\\credentials"]
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
}