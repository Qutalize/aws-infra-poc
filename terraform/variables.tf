# terraform/variables.tf
variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"   # 東京
}

variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックス）"
  type        = string
  default     = "infra-poc"
}

variable "app_bucket_name" {
  description = "アプリバイナリを格納するS3バケット名"
  type        = string
  # terraform.tfvars で値を設定する
}

variable "alert_email" {
  description = "コストアラート通知先メールアドレス"
  type        = string
  # terraform.tfvars で値を設定する
}

variable "ec2_instance_type" {
  description = "EC2インスタンスタイプ（ARM64）"
  type        = string
  # t4g.nano（$0.0042/h）より1段上のt4g.micro（$0.0084/h）を推奨
  # nanoはbcrypt×1 + 30req/sでもCPU飽和してヘルスチェックが失敗するリスクがある
  default     = "t4g.micro"
}

variable "asg_min_size" {
  description = "Auto Scalingの最小インスタンス数"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Auto Scalingの最大インスタンス数"
  type        = number
  default     = 3
}

variable "scale_out_cpu_threshold" {
  description = "スケールアウト発動のCPU使用率閾値（%）"
  type        = number
  default     = 30
}