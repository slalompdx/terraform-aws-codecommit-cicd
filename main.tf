# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A CI/CD PIPELINE WITH CODECOMMIT USING AWS
# This module creates a CodePipeline with CodeBuild that is linked to a CodeCommit repository.
# Note: CodeCommit does not create a master branch initially. Once this script is run, you must clone the repo, and
# then push to origin master.
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

# Generate a unique label for naming resources
module "unique_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.12.0"
  namespace  = var.organization_name
  name       = var.repo_name
  stage      = var.environment
  delimiter  = var.char_delimiter
  attributes = []
  tags       = {}
}

# CodeCommit resources
resource "aws_codecommit_repository" "repo" {
  repository_name = var.repo_name
  description     = "${var.repo_name} repository."
  default_branch  = var.repo_default_branch
}

# CodePipeline resources
resource "aws_s3_bucket" "build_artifact_bucket" {
  bucket        = module.unique_label.id
  acl           = "private"
  force_destroy = var.force_artifact_destroy
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
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_policy.json
}

# CodePipeline policy needed to use CodeCommit and CodeBuild
data "template_file" "codepipeline_policy_template" {
  template = file("${path.module}/iam-policies/codepipeline.tpl")
  vars = {
    aws_kms_key     = aws_kms_key.artifact_encryption_key.arn
    artifact_bucket = aws_s3_bucket.build_artifact_bucket.arn
  }
}

resource "aws_iam_role_policy" "attach_codepipeline_policy" {
  name = "${module.unique_label.name}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = data.template_file.codepipeline_policy_template.rendered

}

# Encryption key for build artifacts
resource "aws_kms_key" "artifact_encryption_key" {
  description             = "artifact-encryption-key"
  deletion_window_in_days = 10
}

# CodeBuild IAM Permissions
data "template_file" "codepipeline_assume_role_policy_template" {
  template = file("${path.module}/iam-policies/codebuild_assume_role.tpl")
}

resource "aws_iam_role" "codebuild_assume_role" {
  name               = "${module.unique_label.name}-codebuild-role"
  assume_role_policy = data.template_file.codepipeline_assume_role_policy_template.rendered
}


data "template_file" "codebuild_policy_template" {
  template = file("${path.module}/iam-policies/codebuild.tpl")
  vars = {
    artifact_bucket         = aws_s3_bucket.build_artifact_bucket.arn
    aws_kms_key             = aws_kms_key.artifact_encryption_key.arn
    codebuild_project_test  = aws_codebuild_project.test_project.id
    codebuild_project_build = aws_codebuild_project.build_project.id
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${module.unique_label.name}-codebuild-policy"
  role = aws_iam_role.codebuild_assume_role.id

  policy = data.template_file.codebuild_policy_template.rendered
}

# CodeBuild Section for the Package stage
resource "aws_codebuild_project" "build_project" {
  name           = "${var.repo_name}-package"
  description    = "The CodeBuild project for ${var.repo_name}"
  service_role   = aws_iam_role.codebuild_assume_role.arn
  build_timeout  = var.build_timeout
  encryption_key = aws_kms_key.artifact_encryption_key.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.build_compute_type
    image           = var.build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = var.build_privileged_override
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.package_buildspec
  }
}

# CodeBuild Section for the Test stage
resource "aws_codebuild_project" "test_project" {
  name           = "${var.repo_name}-test"
  description    = "The CodeBuild project for ${var.repo_name}"
  service_role   = aws_iam_role.codebuild_assume_role.arn
  build_timeout  = var.build_timeout
  encryption_key = aws_kms_key.artifact_encryption_key.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.build_compute_type
    image           = var.build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = var.build_privileged_override
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.test_buildspec
  }
}

# Full CodePipeline
resource "aws_codepipeline" "codepipeline" {
  name     = var.repo_name
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.build_artifact_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.artifact_encryption_key.arn
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

      configuration = {
        RepositoryName = var.repo_name
        BranchName     = var.repo_default_branch
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

      configuration = {
        ProjectName = aws_codebuild_project.test_project.name
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

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }
}
