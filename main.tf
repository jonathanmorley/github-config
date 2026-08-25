terraform {
  required_version = ">= 1.6.0"

  required_providers {
    github = {
      source  = "registry.terraform.io/jonathanmorley/github"
      version = "6.13.0-jm.2"
    }
  }
}

provider "github" {
  owner = "jonathanmorley"
}
