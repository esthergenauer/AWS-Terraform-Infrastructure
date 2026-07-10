# Staging Observability — apply notes
#
# Files:
#   monitoring.tf                         — SNS, Lambda, IAM, CloudWatch alarms
#   lambda/slack_alerts/handler.py        — Slack translator (Python 3.12)
#   modules/eb/main.tf                    — SystemType=enhanced + ConfigDocument
#   outputs.tf                            — monitoring outputs (additive)
#
# Prerequisites:
#   1. Secret exists: staging/slack-alerts-webhook
#      JSON shape: {"webhook_url":"https://hooks.slack.com/services/..."}
#   2. Branch: feat/monitoring-alerts
#
# Apply (staging only):
#   cd environments/staging
#   terraform init
#   terraform plan
#   terraform apply
#
# After apply — expect EB environment update (config-only, no instance replace).
# Metrics ApplicationRequests5xx / RootFilesystemUtil appear within ~1–2 minutes.
#
# Test Slack path:
#   aws sns publish --topic-arn <staging_alerts_sns_topic_arn> --region eu-north-1 \
#     --subject "TEST staging alert" \
#     --message '{"AlarmName":"manual-test","NewStateValue":"ALARM","NewStateReason":"Manual SNS test","StateChangeTime":"now"}'
#
# Cost note:
#   EnvironmentHealth is free. ApplicationRequests5xx/4xx and RootFilesystemUtil
#   are CloudWatch custom metrics (small staging charge). Toggle off via
#   module.eb publish_enhanced_health_metrics = false if needed.
