# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# ---------------------------------------------------------------------------------------------------------------------

# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy into (default: us-west-2)."
  default     = "us-west-2"
}

variable "organization_name" {
  description = "The organization name provisioning the template (e.g. acme)"
  default     = "acme"
}

variable "char_delimiter" {
  description = "The delimiter to use for unique names (default: -)"
  default     = "-"
}

variable "repo_name" {
  description = "The name of the CodeCommit repository (e.g. new-repo)."
  default     = ""
}

variable "repo_default_branch" {
  description = "The name of the default repository branch (default: master)"
  default     = "master"
}

variable "force_artifact_destroy" {
  description = "Force the removal of the artifact S3 bucket on destroy (default: false)."
  default     = "false"
}

variable "environment" {
  description = "The environment being deployed (default: dev)"
  default     = "dev"
}

variable "build_timeout" {
  description = "The time to wait for a CodeBuild to complete before timing out in minutes (default: 5)"
  default     = "5"
}

variable "build_compute_type" {
  description = "The build instance type for CodeBuild (default: BUILD_GENERAL1_SMALL)"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_image" {
  description = "The build image for CodeBuild to use (default: aws/codebuild/nodejs:6.3.1)"
  default     = "aws/codebuild/nodejs:6.3.1"
}

variable "build_privileged_override" {
  description = "Set the build privileged override to 'true' if you are not using a CodeBuild supported Docker base image. This is only relevant to building Docker images"
  default     = "false"
}

variable "test_buildspec" {
  description = "The buildspec to be used for the Test stage (default: buildspec_test.yml)"
  default     = "buildspec_test.yml"
}

variable "package_buildspec" {
  description = "The buildspec to be used for the Package stage (default: buildspec.yml)"
  default     = "buildspec.yml"
}
