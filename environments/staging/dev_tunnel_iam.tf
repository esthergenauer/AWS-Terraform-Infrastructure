# Shared IAM user for developers — SSM port-forward to RDS via bastion (no per-IP whitelist).

data "aws_caller_identity" "current" {}

resource "aws_iam_user" "dev_tunnel" {
  name = "sbl-dev-tunnel"
  tags = merge(local.tags, { Purpose = "developer-db-tunnel" })
}

resource "aws_iam_user_policy" "dev_tunnel" {
  name = "bastion-ssm-port-forward"
  user = aws_iam_user.dev_tunnel.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StartPortForwardingToRdsViaBastion"
        Effect = "Allow"
        Action = ["ssm:StartSession"]
        Resource = [
          "arn:aws:ssm:${var.aws_region}::document/AWS-StartPortForwardingSessionToRemoteHost",
          "arn:aws:ssm:${var.aws_region}::document/SSM-SessionManagerRunShell",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${module.bastion.instance_id}"
        ]
      },
      {
        Sid      = "DescribeBastionForSession"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Sid    = "ManageOwnSessions"
        Effect = "Allow"
        Action = [
          "ssm:TerminateSession",
          "ssm:ResumeSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:session/$${aws:username}-*"
      }
    ]
  })
}
