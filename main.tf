########################################
# Provider
########################################
provider "aws" {
  region = "us-east-1" # Change to your preferred AWS region
}

########################################
# Variables
########################################
variable "default_tags" {
  type = map(string)
  default = {
    Project     = "EC2-Scheduler"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

variable "log_retention_days" {
  type    = number
  default = 30 # Change as needed (7, 14, 30, 60, 90, etc.)
}

########################################
# IAM Role for Lambda
########################################
resource "aws_iam_role" "lambda_role" {
  name = "ec2-scheduler-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.default_tags
}

# Attach AWS-managed basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom EC2 permissions (inline policy — cannot have tags)
resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2-scheduler-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

########################################
# Lambda Packaging - Dependencies + Code
########################################
resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf build
      mkdir -p build
      pip install -r requirements.txt --target build
      cp lambda_function.py build/
    EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/build"
  output_path = "${path.module}/lambda_function.zip"

  depends_on = [null_resource.install_dependencies]
}

########################################
# Lambda Function
########################################
resource "aws_lambda_function" "ec2_scheduler" {
  function_name    = "ec2-instance-scheduler"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  timeout          = 30
  memory_size      = 128

  tags = var.default_tags
}

########################################
# CloudWatch Log Group with Retention
########################################
resource "aws_cloudwatch_log_group" "ec2_scheduler_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ec2_scheduler.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.default_tags
}

########################################
# CloudWatch Event Rule - Run Every Hour
########################################
resource "aws_cloudwatch_event_rule" "hourly" {
  name                = "hourly-ec2-scheduler-trigger"
  description         = "Trigger EC2 scheduler every hour"
  schedule_expression = "cron(0 * * * ? *)"

  tags = var.default_tags
}

########################################
# CloudWatch Event Target
########################################
resource "aws_cloudwatch_event_target" "run_ec2_scheduler" {
  rule      = aws_cloudwatch_event_rule.hourly.name
  target_id = "ec2_scheduler"
  arn       = aws_lambda_function.ec2_scheduler.arn
}

########################################
# Allow EventBridge to Invoke Lambda
########################################
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly.arn
}
