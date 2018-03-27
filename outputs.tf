output "clone_repo_https" {
  value = "${aws_codecommit_repository.repo.clone_url_http}"
}

output "clone_repo_ssh" {
  value = "${aws_codecommit_repository.repo.clone_url_ssh}"
}

output "artifact_bucket" {
  value = "${aws_s3_bucket.build_artifact_bucket.id}"
}
