data "sops_file" "secrets" {
  source_file = "../secrets.enc.yaml"
}

locals {
  cloudflare_token      = data.sops_file.secrets.data["cloudflare_api_token"]
  cloudflare_account_id = data.sops_file.secrets.data["cloudflare_account_id"]
}
