# terraform/backend.tf
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # stateファイルをS3で管理
  # バケット名はterraform initの -backend-config で渡す（セキュリティガイド参照）
  backend "s3" {
    key            = "infra/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-state-lock"   # State Lock用テーブル（1-3で作成済み）
    encrypt        = true
  }
}