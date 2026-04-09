resource "aws_cloudfront_distribution" "main" {
  enabled = true
  comment = "${var.project_name} CDN"

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # デフォルト：キャッシュしない
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true

    forwarded_values {
      query_string = true
      cookies { forward = "none" }
    }
  }

  # /api/info 
  ordered_cache_behavior {
    path_pattern           = "/api/info"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 60 
    max_ttl                = 300
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  # /api/heavy 
  ordered_cache_behavior {
    path_pattern           = "/api/heavy"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0 #test5限定
    default_ttl            = 10 #test5限定
    max_ttl                = 30 #test5限定
    compress               = true #test5限定
      forwarded_values { #test5限定
      query_string = false
      cookies { forward = "none" }
    }
    # cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Project = var.project_name }
}