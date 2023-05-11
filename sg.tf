# Security groups
resource "yandex_vpc_security_group" "alb_main_sg" {
  count       = var.enable_default_rules ? 1 : 0
  name        = "alb-sg-main-${random_string.unique_id.result}"
  description = "ALB security group"
  network_id  = var.network_id

  ingress {
    protocol       = "TCP"
    description    = "External HTTP rule."
    v4_cidr_blocks = var.allowed_ips
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "External HTTPS rule."
    v4_cidr_blocks = var.allowed_ips
    port           = 443
  }

  ingress {
    protocol          = "TCP"
    description       = "Rule allows availability checks from load balancer's address range."
    predefined_target = "loadbalancer_healthchecks"
    port              = 30080
  }

  egress {
    protocol       = "ANY"
    description    = "Rule allows all outgoing traffic."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# This group defines custom security rules
resource "yandex_vpc_security_group" "alb_custom_rules_sg" {
  count       = length(var.custom_ingress_rules) > 0 || length(var.custom_egress_rules) > 0 ? 1 : 0
  name        = "alb-custom-rules-group-${random_string.unique_id.result}"
  description = "This group defines custom ingress / egress security rules."
  network_id  = var.network_id
}

resource "yandex_vpc_security_group_rule" "ingress_rules" {
  for_each = var.custom_ingress_rules

  security_group_binding = yandex_vpc_security_group.alb_custom_rules_sg[0].id
  direction              = "ingress"
  description            = lookup(each.value, "description", null)
  v4_cidr_blocks         = lookup(each.value, "v4_cidr_blocks", [])
  from_port              = lookup(each.value, "from_port", null)
  to_port                = lookup(each.value, "to_port", null)
  port                   = lookup(each.value, "port", null)
  protocol               = lookup(each.value, "protocol", "TCP")
}

resource "yandex_vpc_security_group_rule" "egress_rules" {
  for_each = var.custom_egress_rules

  security_group_binding = yandex_vpc_security_group.alb_custom_rules_sg[0].id
  direction              = "egress"
  description            = lookup(each.value, "description", null)
  v4_cidr_blocks         = lookup(each.value, "v4_cidr_blocks", [])
  from_port              = lookup(each.value, "from_port", null)
  to_port                = lookup(each.value, "to_port", null)
  port                   = lookup(each.value, "port", null)
  protocol               = lookup(each.value, "protocol", "TCP")
}
