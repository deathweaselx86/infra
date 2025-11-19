data "sops_file" "secrets" {
  source_file = "../secrets.enc.yaml"
}

data "http" "ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  aws_access_key_id     = data.sops_file.secrets.data["aws_access_key_id"]
  aws_secret_access_key = data.sops_file.secrets.data["aws_secret_access_key"]
  availability_zone     = "us-east-1a"
  src_ip                = "${chomp(data.http.ip.response_body)}/32"
  ami                   = "ami-0c02fb55b2188e59d"
}
