# basic-example
This is a basic example of using the `terraform-aws-codecommit-cicd` Terraform module.

`main.tf` contains the creation of the module with sample parameters. It provisions a new AWS CodeCommit repository `slalom-devops` with a default branch of `master`. This repository becomes a Source stage for the AWS CodePipeline that is created. This pipeline contains two AWS CodeBuild projects, one for the Test stage, and another for the Build stage.

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

### Sample buildspec files
In this example directory there is `buildspec_test.yml` and `buildspec.yml`. These are sample build spec files you can add to the root of your new repository in CodeCommit. The test buildspec files contains the `artifacts` section that copies the entire repo to the build stage to be used there.
