# ALB TG IDs / Names
output "alb_target_group_ids" {
  description = "ALB target group IDs."
  value       = try(module.yc-alb.alb_target_group_ids, null)
}
output "alb_target_group_names" {
  description = "ALB target group names."
  value       = try(module.yc-alb.alb_target_group_names, null)
}

# ALB BG IDs / Names
output "alb_backend_group_ids" {
  description = "ALB backend group IDs."
  value       = try(module.yc-alb.alb_backend_group_ids, null)
}
output "alb_backend_group_names" {
  description = "ALB backend group names."
  value       = try(module.yc-alb.alb_backend_group_names, null)
}

# ALB HR IDs / Names
output "alb_http_router_ids" {
  description = "ALB http router IDs."
  value       = try(module.yc-alb.alb_http_router_ids, null)
}
output "alb_http_router_names" {
  description = "ALB http router names."
  value       = try(module.yc-alb.alb_http_router_names, null)
}

# ALB VH IDs / Names
output "alb_virtual_host_ids" {
  description = "ALB virtual host IDs."
  value       = try(module.yc-alb.alb_virtual_host_ids, null)
}
output "alb_virtual_host_names" {
  description = "ALB virtual host names."
  value       = try(module.yc-alb.alb_virtual_host_names, null)
}

# ALB LB ID / Name
output "alb_load_balancer_id" {
  description = "ALB laod balancer ID."
  value       = try(module.yc-alb.alb_load_balancer_id, null)
}
output "alb_load_balancer_name" {
  description = "ALB laod balancer name."
  value       = try(module.yc-alb.alb_load_balancer_name, null)
}

# ALB LB Public IPs
output "alb_load_balancer_public_ips" {
  description = "ALB Load Balancer Public IPs."
  value = try(module.yc-alb.alb_load_balancer_public_ips, null)
}

# ALB LB DNS name
output "alb_dns_record_cname" {
  description = "ALB DNS CNAME"
  value = try(module.yc-alb.alb_dns_record_cname, null)
}