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

resource "cloudflare_dns_record" "kd3bwz_net_root" {
    name = "kd3bwz.net"
    type = "A"
    content = "152.42.153.153"
    zone_id = cloudflare_zone.kd3bwz_net.id
    ttl = 1
    proxied = true
}

resource "cloudflare_dns_record" "kd3bwz_dmarc" {
    name = "_dmarc.kd3bwz.net"
    type = "TXT"
    content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:admin@deathweasel.io\""
    ttl = 1
    zone_id = cloudflare_zone.kd3bwz_net.id
}

resource "cloudflare_dns_record" "kd3bwz_domainkey" {
    name = "*._domainkey.kd3bwz.net"
    type = "TXT"
    content = "\"v=DKIM1; p=\""
    ttl = 1
    zone_id = cloudflare_zone.kd3bwz_net.id
}

resource "cloudflare_dns_record" "kd3bwz_net_spf" {
    name = "kd3bwz.net"
    type = "TXT"
    content = "\"v=spf1 -all\""
    ttl = 1 
    zone_id = cloudflare_zone.kd3bwz_net.id

}
