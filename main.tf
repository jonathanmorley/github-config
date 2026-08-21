terraform {
  cloud {
    hostname     = "app.terraform.io"
    organization = "jonathanmorley"

    workspaces {
      name = "github-config"
    }
  }

  required_version = ">= 1.6.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = "jonathanmorley"
}
