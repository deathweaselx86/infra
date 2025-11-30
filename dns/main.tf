data "cloudflare_registrar_domain" "kd3bwz_net" {
  account_id  = local.cloudflare_account_id
  domain_name = "kd3bwz.net"
}

resource "cloudflare_zone" "kd3bwz_net" {
  account = {
    id = local.cloudflare_account_id
  }
  name = "kd3bwz.net"
  type = "full"
}

resource "cloudflare_zone" "mckinnie_org" {
  account = {
    id = local.cloudflare_account_id
  }
  name = "mckinnie.org"
  type = "full"
}

resource "cloudflare_dns_record" "bastion_kd3bwz_net" {
  name = "bastion.kd3bwz.net"
  type = "A"
  content = data.terraform_remote_state.aws.outputs.bastion_public_ip
  zone_id = cloudflare_zone.kd3bwz_net.id
  ttl = 1
}

resource "cloudflare_dns_record" "kd3bwz_net_root" {
  name    = "kd3bwz.net"
  type    = "A"
  content = var.kd3bwz_root_ip
  zone_id = cloudflare_zone.kd3bwz_net.id
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "kd3bwz_dmarc" {
  name    = "_dmarc.kd3bwz.net"
  type    = "TXT"
  content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:admin@deathweasel.io\""
  ttl     = 1
  zone_id = cloudflare_zone.kd3bwz_net.id
}

resource "cloudflare_dns_record" "kd3bwz_domainkey" {
  name    = "*._domainkey.kd3bwz.net"
  type    = "TXT"
  content = "\"v=DKIM1; p=\""
  ttl     = 1
  zone_id = cloudflare_zone.kd3bwz_net.id
}

resource "cloudflare_dns_record" "kd3bwz_net_spf" {
  name    = "kd3bwz.net"
  type    = "TXT"
  content = "\"v=spf1 -all\""
  ttl     = 1
  zone_id = cloudflare_zone.kd3bwz_net.id

}

data "terraform_remote_state" "aws" {
  backend = "s3"
  config = {
    bucket = "jmckinnie-cloud-infra"
    key = "k8s/terraform.tfstate"
    region = "us-east-1"
  }
}
