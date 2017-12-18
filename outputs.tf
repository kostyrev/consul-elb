output "load_balancer_name" {
  value = "${aws_elb.consul.name}"
}

output "load_balancer_dns_name" {
  value = "${aws_elb.consul.dns_name}"
}

output "load_balancer_zone_id" {
  value = "${aws_elb.consul.zone_id}"
}

output "load_balancer_security_group_id" {
  value = "${aws_security_group.consul.id}"
}

output "fully_qualified_domain_name" {
  # Hack datasource error on count = 0
  value = "${element(concat(aws_route53_record.consul_elb.*.fqdn, list("")), 0)}"
}
