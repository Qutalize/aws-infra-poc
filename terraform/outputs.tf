# terraform/outputs.tf
output "alb_dns_name" {
  description = "ALBのDNS名（直接アクセス用）"
  value       = aws_lb.main.dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFrontのドメイン名（CDN経由のアクセス用）"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "dynamodb_table_name" {
  description = "DynamoDBテーブル名"
  value       = aws_dynamodb_table.records.name
}

output "asg_name" {
  description = "Auto Scaling Group名"
  value       = aws_autoscaling_group.app.name
}

output "test_urls" {
  description = "負荷テスト用URL一覧"
  value = {
    alb_heavy    = "http://${aws_lb.main.dns_name}/api/heavy"
    alb_info     = "http://${aws_lb.main.dns_name}/api/info"
    cf_heavy     = "https://${aws_cloudfront_distribution.main.domain_name}/api/heavy"
    cf_info      = "https://${aws_cloudfront_distribution.main.domain_name}/api/info"
    health_check = "http://${aws_lb.main.dns_name}/health"
  }
}