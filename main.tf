terraform {
  cloud {
    hostname = "app.terraform.io"
    organization = "jonathanmorley"
    workspaces {
      name = "github-config"
    }
  }

  required_version = ">= 1.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = "jonathanmorley"
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem
  }
}
