data "cloudflare_registrar_domain" "kd3bwz_net" {
    account_id = local.cloudflare_account_id
    domain_name = "kd3bwz.net"
}

resource "cloudflare_zone" "kd3bwz_net" {
    account = {
        id = local.cloudflare_account_id
    }
    name = "kd3bwz.net"
    type = "full"
}
