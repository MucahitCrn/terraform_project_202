terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.48.0"
    }
    github = {
      source = "integrations/github"
      version = "5.12.0"
    }
  }
}
provider "aws" {
    region = "us-east-1"  
}
provider "github" {
    token= "write-here-token"
}