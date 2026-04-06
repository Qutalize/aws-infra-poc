# terraform/compute.tf

# Amazon Linux 2023（ARM64）最新AMIを自動取得
data "aws_ami" "amazon_linux_2023_arm64" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2起動テンプレート
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023_arm64.id
  instance_type = var.ec2_instance_type

  iam_instance_profile { name = aws_iam_instance_profile.ec2_profile.name }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
  }

  # EC2起動時に自動実行されるスクリプト
  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1
    echo "=== User Data 開始: $(date) ==="

    yum update -y

    echo "S3からバイナリをダウンロード..."
    aws s3 cp s3://${var.app_bucket_name}/api-server /opt/api-server \
      --region ${var.aws_region}
    chmod +x /opt/api-server

    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

    cat > /etc/systemd/system/api-server.service << SERVICE
    [Unit]
    Description=Go API Server
    After=network.target

    [Service]
    Type=simple
    User=nobody
    Environment="PORT=8080"
    Environment="AWS_REGION=${var.aws_region}"
    Environment="DYNAMODB_TABLE_NAME=${aws_dynamodb_table.records.name}"
    Environment="INSTANCE_ID=$${INSTANCE_ID}"
    ExecStart=/opt/api-server
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable api-server
    systemctl start api-server
    echo "=== 起動完了: $(date) ==="
  USERDATA
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project_name}-ec2", Project = var.project_name }
  }

  lifecycle { create_before_destroy = true }
}

# ALB
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1a.id, aws_subnet.public_1c.id]
  tags               = { Name = "${var.project_name}-alb", Project = var.project_name }
}

# ターゲットグループ
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }
  tags = { Project = var.project_name }
}

# ALBリスナー（80番ポート）
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-asg"
  desired_capacity          = var.asg_min_size
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  vpc_zone_identifier       = [aws_subnet.public_1a.id, aws_subnet.public_1c.id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences { min_healthy_percentage = 50 }
  }

  tag {
    key = "Name"
    value = "${var.project_name}-ec2"
    propagate_at_launch = true 
    }
}

# スケールアウトポリシー
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

# スケールインポリシー
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# CloudWatch：CPU高負荷でスケールアウト
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.app.name }
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]
  tags                = { Project = var.project_name }
}

# CloudWatch：CPU低負荷でスケールイン
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 10
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.app.name }
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]
  tags                = { Project = var.project_name }
}