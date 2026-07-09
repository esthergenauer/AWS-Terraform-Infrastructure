data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  build_project_name = "${var.name}-build"
  account_id         = data.aws_caller_identity.current.account_id
  region             = data.aws_region.current.name

  eb_application_arn = "arn:aws:elasticbeanstalk:${local.region}:${local.account_id}:application/${var.eb_application_name}"
  eb_environment_arn = "arn:aws:elasticbeanstalk:${local.region}:${local.account_id}:environment/${var.eb_application_name}/${var.eb_environment_name}"
  eb_version_arn     = "arn:aws:elasticbeanstalk:${local.region}:${local.account_id}:applicationversion/${var.eb_application_name}/*"
  eb_managed_bucket  = "arn:aws:s3:::elasticbeanstalk-${local.region}-${local.account_id}/*"
}

resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifact_bucket_name
  tags   = merge(var.tags, { Name = var.artifact_bucket_name })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "codebuild" {
  name = "${var.name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.name}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.build_project_name}*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticbeanstalk:DescribeConfigurationSettings",
          "elasticbeanstalk:DescribeEnvironments",
          "elasticbeanstalk:UpdateEnvironment"
        ]
        Resource = [
          local.eb_application_arn,
          local.eb_environment_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_github_token" {
  count = var.github_token_secret_arn != null ? 1 : 0

  name = "${var.name}-codebuild-github-token"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.github_token_secret_arn
    }]
  })
}

resource "aws_codebuild_project" "this" {
  name         = local.build_project_name
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "APP_ENV"
      value = var.environment
    }

    environment_variable {
      name  = "DEPLOY_ENV"
      value = var.environment
    }

    environment_variable {
      name  = "FRONTEND_BRANCH"
      value = var.frontend_branch
    }

    environment_variable {
      name  = "FRONTEND_REPO"
      value = var.frontend_repo
    }

    environment_variable {
      name  = "SOURCE_BRANCH"
      value = var.source_branch
    }

    environment_variable {
      name  = "EB_APPLICATION_NAME"
      value = var.eb_application_name
    }

    environment_variable {
      name  = "EB_ENVIRONMENT_NAME"
      value = var.eb_environment_name
    }

    environment_variable {
      name  = "AWS_REGION"
      value = local.region
    }

    dynamic "environment_variable" {
      for_each = var.github_token_secret_arn != null ? [1] : []
      content {
        name      = "GITHUB_TOKEN"
        type      = "SECRETS_MANAGER"
        value     = var.github_token_secret_arn
      }
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_path
  }

  tags = merge(var.tags, { Name = local.build_project_name })
}

resource "aws_iam_role" "pipeline" {
  name = "${var.name}-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "pipeline" {
  name = "${var.name}-pipeline-policy"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:GetBucketVersioning"]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = var.codestar_connection_arn
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = aws_codebuild_project.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "elasticbeanstalk:CreateApplicationVersion",
          "elasticbeanstalk:UpdateEnvironment"
        ]
        Resource = [
          local.eb_application_arn,
          local.eb_environment_arn,
          local.eb_version_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticbeanstalk:DescribeApplications",
          "elasticbeanstalk:DescribeApplicationVersions",
          "elasticbeanstalk:DescribeEnvironments",
          "elasticbeanstalk:DescribeEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = [
          "${aws_s3_bucket.artifacts.arn}/*",
          local.eb_managed_bucket
        ]
      }
    ]
  })
}

resource "aws_codepipeline" "this" {
  name     = var.name
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.source_repo
        BranchName       = var.source_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName = var.eb_application_name
        EnvironmentName = var.eb_environment_name
      }
    }
  }

  tags = merge(var.tags, { Name = var.name })

  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "Source"

      push {
        branches {
          includes = [var.source_branch]
        }
      }
    }
  }
}
