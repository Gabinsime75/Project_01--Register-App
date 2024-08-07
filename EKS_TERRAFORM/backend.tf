terraform {
  backend "s3" {
    bucket         = "registerapp-bucket2"
    key            = "EKS/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "registerapp-db-table2"
  }
}
