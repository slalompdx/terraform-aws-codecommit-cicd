# terraform-aws-codecommit-cicd
Terraform module that stands up a new AWS CodeCommit repository integrated with AWS CodePipeline. The CodePipeline consists of three stages:

1. A Source stage that is fed by the repository.
2. A Test stage that uses the artifacts of the Source and executes commands in `buildspec_test.yml`.
3. A Package stage that uses the artrifacts of the Test stage and excutes commands in `buildspec.yml`.

## Usage
```hcl
module "codecommit-cicd" {
    source                 = "git::https://github.com/slalompdx/terraform-aws-codecommit-cicd.git?ref=master"
    repo_name                 = "new-test-repo"              # Required
    organization_name         = "slalom"                     # Required
    repo_default_branch       = "master"                     # Default value
    aws_region                = "us-west-2"                  # Default value
    char_delimiter            = "-"                          # Default value
    environment               = "dev"                        # Default value
    build_timeout             = "5"                          # Default value
    build_compute_type        = "BUILD_GENERAL1_SMALL"       # Default value
    build_image               = "aws/codebuild/nodejs:6.3.1" # Default value
    build_privileged_override = "false"                      # Default value
    test_buildspec            = "buildspec_test.yml"         # Default value
    package_buildspec         = "buildspec.yml"              # Default value
    force_artifact_destroy    = "false"                      # Default value
}
```

### CodeCommit Note
New repositories are **not** created with their default branch. Therefore, once the module has ran you must clone the repository, add a file, and then push to `origin/<repo_default_branch>` to initialize the repository.

Your command line execution might look something like this:

```bash
$>terraform apply
$>git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/slalom-devops
$>cd slalom-devops
$>echo 'hello world' > touch.txt
$>git commit -a -m 'init master'
$>git push -u origin master
```