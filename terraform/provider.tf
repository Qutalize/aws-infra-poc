# terraform/provider.tf
provider "aws" {
  region = var.aws_region   # ap-northeast-1（東京）
}

# 請求アラーム用のみus-east-1（AWSの仕様・変更不可）
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}