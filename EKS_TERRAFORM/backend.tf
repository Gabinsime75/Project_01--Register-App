terraform {
  backend "s3" {
    bucket         = "proj01-regapp-remote-nova-bucket"
    key            = "EKS/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "proj01-regapp-remote-nova-table"
  }
}
