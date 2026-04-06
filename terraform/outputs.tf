output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "ALBのDNS名"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.main.domain_name
  description = "CloudFrontのドメイン名"
}
