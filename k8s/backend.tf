terraform {
  backend "s3" {
    bucket         = "jmckinnie-cloud-infra"
    key            = "k8s/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
