terraform {
  required_version = ">= 1.0"

  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.12.0"
    }
  }
}
