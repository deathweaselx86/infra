data "sops_file" "secrets" {
  source_file = "../secrets.enc.yaml"
}

data "http" "ip" {
  url = "https://checkip.amazonaws.com"
}

data "local_file" "cloudinit" {
  filename = "${path.module}/cloudinit.sh"
}

locals {
  aws_access_key_id     = data.sops_file.secrets.data["aws_access_key_id"]
  aws_secret_access_key = data.sops_file.secrets.data["aws_secret_access_key"]
  availability_zone     = "us-east-1a"
  src_ip                = "${chomp(data.http.ip.response_body)}/32"
  ami                   = "ami-083f1fc4f8bcff379"
  burstable_ami         = "ami-0c1f44f890950b53c"
}
