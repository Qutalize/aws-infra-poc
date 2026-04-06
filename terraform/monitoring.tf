# terraform/monitoring.tf

# SNSトピック（us-east-1固定・AWSの仕様）
resource "aws_sns_topic" "billing_alert" {
  provider = aws.us_east_1
  name     = "${var.project_name}-billing-alert"
}

resource "aws_sns_topic_subscription" "billing_email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.billing_alert.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Billing Alarm（$5到達・us-east-1固定）
resource "aws_cloudwatch_metric_alarm" "billing_5usd" {
  provider            = aws.us_east_1
  alarm_name          = "${var.project_name}-billing-5usd"
  alarm_description   = "月の請求額が$5を超えた場合に通知"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  statistic           = "Maximum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { Currency = "USD" }
  alarm_actions       = [aws_sns_topic.billing_alert.arn]
  tags                = { Project = var.project_name }
}

# AWS Budget（グローバルサービス・リージョン指定不要）
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}