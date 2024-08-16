terraform {
  backend "s3" {
    bucket         = "proj01-reg-app-remote-bucket"
    key            = "EKS/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "Proj01_RegApp_State-Lock"
  }
}
