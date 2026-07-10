# =============================================================================
# Production FinOps — scheduled Auto Scaling (night scale-down / morning scale-up)
# =============================================================================
# Saves EC2 cost overnight while maintaining HA during business hours.
# Times use var.finops_schedule_timezone (default Asia/Jerusalem).
# =============================================================================

data "aws_autoscaling_groups" "eb_prod" {
  filter {
    name   = "tag:elasticbeanstalk:environment-name"
    values = [module.eb.environment_name]
  }

  depends_on = [module.eb]
}

locals {
  eb_prod_asg_name = try(tolist(data.aws_autoscaling_groups.eb_prod.names)[0], null)
}

resource "aws_autoscaling_schedule" "finops_night_scale_down" {
  count = local.eb_prod_asg_name != null ? 1 : 0

  scheduled_action_name  = "finops-night-scale-down"
  autoscaling_group_name = local.eb_prod_asg_name

  min_size         = var.finops_night_min_size
  max_size         = var.eb_max_instances
  desired_capacity = var.finops_night_min_size

  recurrence = var.finops_scale_down_cron
  time_zone  = var.finops_schedule_timezone

  lifecycle {
    # EB may recreate the ASG name on major platform changes — re-apply schedules.
    create_before_destroy = true
  }
}

resource "aws_autoscaling_schedule" "finops_morning_scale_up" {
  count = local.eb_prod_asg_name != null ? 1 : 0

  scheduled_action_name  = "finops-morning-scale-up"
  autoscaling_group_name = local.eb_prod_asg_name

  min_size         = var.finops_day_min_size
  max_size         = var.eb_max_instances
  desired_capacity = var.finops_day_min_size

  recurrence = var.finops_scale_up_cron
  time_zone  = var.finops_schedule_timezone

  lifecycle {
    create_before_destroy = true
  }
}
