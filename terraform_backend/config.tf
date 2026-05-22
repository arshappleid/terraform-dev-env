terraform {
  backend "s3" {
    bucket = "example-bucket"
    key    = "path/to/state"
    region = "us-east-1"
    assume_role = {
      role_arn = "arn:aws:iam::PRODUCTION-ACCOUNT-ID:role/Terraform"
    }
  }
}
