# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.8 AND ABOVE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.9.3"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ELB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elb" "consul" {
  name = "${var.name}"

  internal                    = "${var.internal}"
  cross_zone_load_balancing   = "${var.cross_zone_load_balancing}"
  idle_timeout                = "${var.idle_timeout}"
  connection_draining         = "${var.connection_draining}"
  connection_draining_timeout = "${var.connection_draining_timeout}"

  security_groups    = ["${aws_security_group.consul.id}"]
  subnets            = ["${var.subnet_ids}"]

  # Run the ELB in TCP passthrough mode
  listener {
    lb_port           = "${var.lb_port}"
    lb_protocol       = "TCP"
    instance_port     = "${var.consul_api_port}"
    instance_protocol = "TCP"
  }

  listener {
    lb_port           = 8300
    lb_protocol       = "TCP"
    instance_port     = 8300
    instance_protocol = "TCP"
  }

  listener {
    lb_port           = 8301
    lb_protocol       = "TCP"
    instance_port     = 8301
    instance_protocol = "TCP"
  }

  health_check {
    target              = "${var.health_check_protocol}:${var.consul_api_port}${var.health_check_path}"
    interval            = "${var.health_check_interval}"
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
    timeout             = "${var.health_check_timeout}"
  }

  tags {
    Name = "${var.name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP THAT CONTROLS WHAT TRAFFIC CAN GO IN AND OUT OF THE ELB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "consul" {
  name        = "${var.name}-elb"
  description = "Security group for the ${var.name} ELB"
  vpc_id      = "${var.vpc_id}"
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.consul.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE CONSUL-SPECIFIC INBOUND/OUTBOUND RULES COME FROM THE CONSUL-SECURITY-GROUP-RULES MODULE
# ---------------------------------------------------------------------------------------------------------------------
module "security_group_rules" {
  source                      = "git::git@github.com:hashicorp/terraform-aws-consul.git//modules/consul-security-group-rules?ref=v0.2.2"
  security_group_id           = "${aws_security_group.consul.id}"
  allowed_inbound_cidr_blocks = ["${var.allowed_inbound_cidr_blocks}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONALLY CREATE A ROUTE 53 ENTRY FOR THE ELB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "consul_elb" {
  count = "${var.create_dns_entry}"

  zone_id = "${var.hosted_zone_id}"
  name    = "${var.domain_name}"
  type    = "A"

  alias {
    name    = "${aws_elb.consul.dns_name}"
    zone_id = "${aws_elb.consul.zone_id}"

    # When set to true, if either none of the ELB's EC2 instances are healthy or the ELB itself is unhealthy,
    # Route 53 routes queries to "other resources." But since we haven't defined any other resources, we'd rather
    # avoid any latency due to switchovers and just wait for the ELB and consul instances to come back online.
    # For more info, see http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-alias.html#rrsets-values-alias-evaluate-target-health
    evaluate_target_health = false
  }
}
