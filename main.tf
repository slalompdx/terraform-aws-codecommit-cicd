# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A CI/CD PIPELINE WITH CODECOMMIT USING AWS
# This module creates a CodePipeline with CodeBuild that is linked to a CodeCommit repository.
# Note: CodeCommit does not create a master branch initially. Once this script is run, you must clone the repo, and
# then push to origin master.
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = "${var.aws_region}"
}

# Generate a unique label for naming resources
module "unique_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.3.1"
  namespace  = "${var.organization_name}"
  name       = "${var.repo_name}"
  stage      = "${var.environment}"
  delimiter  = "${var.char_delimiter}"
  attributes = []
  tags       = "${map()}"
}

# CodeCommit resources
resource "aws_codecommit_repository" "repo" {
  repository_name = "${var.repo_name}"
  description     = "${var.repo_name} repository."
  default_branch  = "${var.repo_default_branch}"
}

# CodePipeline resources
resource "aws_s3_bucket" "build_artifact_bucket" {
  bucket        = "${module.unique_label.id}"
  acl           = "private"
  force_destroy = "${var.force_artifact_destroy}"
}

data "aws_iam_policy_document" "codepipeline_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "${module.unique_label.name}-codepipeline-role"
  assume_role_policy = "${data.aws_iam_policy_document.codepipeline_assume_policy.json}"
}

# CodePipeline policy needed to use CodeCommit and CodeBuild
resource "aws_iam_role_policy" "attach_codepipeline_policy" {
  name = "${module.unique_label.name}-codepipeline-policy"
  role = "${aws_iam_role.codepipeline_role.id}"

  policy = <<EOF
{
    "Statement": [
        {
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketVersioning"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::codepipeline*",
                "arn:aws:s3:::elasticbeanstalk*"
            ],
            "Effect": "Allow"
        },
        {
            "Action": [
                "codecommit:CancelUploadArchive",
                "codecommit:GetBranch",
                "codecommit:GetCommit",
                "codecommit:GetUploadArchiveStatus",
                "codecommit:UploadArchive"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:RegisterApplicationRevision"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "elasticbeanstalk:*",
                "ec2:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "cloudwatch:*",
                "s3:*",
                "sns:*",
                "cloudformation:*",
                "rds:*",
                "sqs:*",
                "ecs:*",
                "iam:PassRole"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "lambda:InvokeFunction",
                "lambda:ListFunctions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "opsworks:CreateDeployment",
                "opsworks:DescribeApps",
                "opsworks:DescribeCommands",
                "opsworks:DescribeDeployments",
                "opsworks:DescribeInstances",
                "opsworks:DescribeStacks",
                "opsworks:UpdateApp",
                "opsworks:UpdateStack"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStacks",
                "cloudformation:UpdateStack",
                "cloudformation:CreateChangeSet",
                "cloudformation:DeleteChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:SetStackPolicy",
                "cloudformation:ValidateTemplate",
                "iam:PassRole"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "kms:DescribeKey",
                "kms:GenerateDataKey*",
                "kms:Encrypt",
                "kms:ReEncrypt*",
                "kms:Decrypt"
            ],
            "Resource": "${aws_kms_key.artifact_encryption_key.arn}",
            "Effect": "Allow"
        }
    ],
    "Version": "2012-10-17"
}
EOF
}

# Encryption key for build artifacts
resource "aws_kms_key" "artifact_encryption_key" {
  description             = "artifact-encryption-key"
  deletion_window_in_days = 10
}

# CodeBuild IAM Permissions
resource "aws_iam_role" "codebuild_assume_role" {
  name = "${module.unique_label.name}-codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${module.unique_label.name}-codebuild-policy"
  role = "${aws_iam_role.codebuild_assume_role.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
       "s3:PutObject",
       "s3:GetObject",
       "s3:GetObjectVersion",
       "s3:GetBucketVersioning"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Effect": "Allow",
      "Resource": [
        "${aws_codebuild_project.build_project.id}",
        "${aws_codebuild_project.test_project.id}"
      ],
      "Action": [
        "codebuild:*"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Action": [
        "kms:DescribeKey",
        "kms:GenerateDataKey*",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:Decrypt"
      ],
      "Resource": "${aws_kms_key.artifact_encryption_key.arn}",
      "Effect": "Allow"
    }
  ]
}
POLICY
}

# CodeBuild Section for the Package stage
resource "aws_codebuild_project" "build_project" {
  name           = "${var.repo_name}-package"
  description    = "The CodeBuild project for ${var.repo_name}"
  service_role   = "${aws_iam_role.codebuild_assume_role.arn}"
  build_timeout  = "${var.build_timeout}"
  encryption_key = "${aws_kms_key.artifact_encryption_key.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "${var.build_compute_type}"
    image        = "${var.build_image}"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${var.package_buildspec}"
  }
}

# CodeBuild Section for the Test stage
resource "aws_codebuild_project" "test_project" {
  name           = "${var.repo_name}-test"
  description    = "The CodeBuild project for ${var.repo_name}"
  service_role   = "${aws_iam_role.codebuild_assume_role.arn}"
  build_timeout  = "${var.build_timeout}"
  encryption_key = "${aws_kms_key.artifact_encryption_key.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "${var.build_compute_type}"
    image        = "${var.build_image}"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${var.test_buildspec}"
  }
}

# Full CodePipeline
resource "aws_codepipeline" "codepipeline" {
  name     = "${var.repo_name}"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store = {
    location = "${aws_s3_bucket.build_artifact_bucket.bucket}"
    type     = "S3"

    encryption_key = {
      id   = "${aws_kms_key.artifact_encryption_key.arn}"
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source"]

      configuration {
        RepositoryName = "${var.repo_name}"
        BranchName     = "${var.repo_default_branch}"
      }
    }
  }

  stage {
    name = "Test"

    action {
      name             = "Test"
      category         = "Test"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source"]
      output_artifacts = ["tested"]
      version          = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.test_project.name}"
      }
    }
  }

  stage {
    name = "Package"

    action {
      name             = "Package"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["tested"]
      output_artifacts = ["packaged"]
      version          = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.build_project.name}"
      }
    }
  }
}
