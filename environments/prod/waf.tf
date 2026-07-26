# =============================================================================
# Production WAF — OWASP-oriented protection on the EB Application Load Balancer
# =============================================================================

data "aws_lbs" "eb_prod" {
  tags = {
    "elasticbeanstalk:environment-name" = module.eb.environment_name
  }

  depends_on = [module.eb]
}

locals {
  eb_prod_alb_arn = try(tolist(data.aws_lbs.eb_prod.arns)[0], null)
}

module "waf" {
  count  = local.eb_prod_alb_arn != null ? 1 : 0
  source = "../../modules/waf"

  name    = "${var.project_name}-prod"
  alb_arn = local.eb_prod_alb_arn

  rate_limit = var.waf_rate_limit_per_ip

  tags = local.tags
}
