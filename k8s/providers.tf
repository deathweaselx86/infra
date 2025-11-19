provider "aws" {
  region     = "us-east-1"
  access_key = local.aws_access_key_id
  secret_key = local.aws_secret_access_key
  default_tags {
    tags = {
      belongs_to = "homelab-k8s"
      managed_by = "terraform"
    }
  }
}
