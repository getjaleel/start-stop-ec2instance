provider "aws" {
  region = var.region
}

terraform {

  # This bucket is used to store/retrieve the Terraform state in/from S3. The bucket should be changed to the one used
  # in your deployment. If the bucket does not exist, you will need to create it.
  backend "s3" {
    bucket = "ga-tf-state"
    # Key is the path to the Terraform state file in the bucket. It should be unique. replace it with your key 
    # (e.g. using your environment or account alias).
    key     = "ec2-start-stop-2/sandbox/terraform.tfstate" # Variable cannot be used here
    region  = "ap-southeast-2"                             # Variable cannot be used here
    encrypt = true

    # This table prevents two users from running 'terraform apply' at the same time. Replace it with your table name. 
    dynamodb_table = "terraform-lock"
  }
}

resource "aws_iam_role" "ec2_start_stop_lambda_role" {
  name = "ec2-start-stop-lambda-role-tf"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "ec2-start-stop-lampda-policy-tf"
  role = aws_iam_role.ec2_start_stop_lambda_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "ec2:*",
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": "logs:CreateLogGroup",
        "Resource": "arn:aws:logs:${var.region}:*"
      },
      {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
        ],
        "Resource": ["arn:aws:logs:${var.region}:*"]
      }
    ]
  }
  EOF
}

resource "aws_lambda_permission" "allow_start_rule_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatchStart"
  action        = "lambda:InvokeFunction"
  function_name = module.ec2_start_stop_lambda.lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = module.cloudwatch_ec2_start.cw_event_rule_arn
}

resource "aws_lambda_permission" "allow_stop_rule_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatchStop"
  action        = "lambda:InvokeFunction"
  function_name = module.ec2_start_stop_lambda.lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = module.cloudwatch_ec2_stop.cw_event_rule_arn
}

resource "null_resource" "file_prep" {

  triggers = {
    code_change = (filesha256("${path.module}/functions/ec2-start-stop/ec2-start-stop-tf.py"))
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/ec2-start-stop/ec2-start-stop-tf.py"
  output_path = "${path.module}/functions/ec2-start-stop-py.zip"
  depends_on  = [null_resource.file_prep]
}

module "ec2_start_stop_lambda" {
  source             = "./modules/lambda"
  lambda_role_arn    = aws_iam_role.ec2_start_stop_lambda_role.arn
  lambda_name        = "ec2-start-stop-tf"
  lambda_description = "The script starts and stops ec2 instances at a scheduled time"
  lambda_zip_name    = data.archive_file.lambda_zip.output_path
  lambda_hash        = filesha256("${path.module}/functions/ec2-start-stop-py.zip")
}

module "cloudwatch_ec2_start" {
  source = "./modules/cloudwatch"

  # Rule
  cw_event_rule_name        = "start-every-day-tf"
  cw_event_rule_description = "Fires every weekday before business hours. GMT based. Region's time zone should be considered."
  cw_event_rule_schedule    = "cron(30 21 ? * SUN-THU *)"

  # Target
  target_arn   = module.ec2_start_stop_lambda.lambda_arn
  target_input = <<EOF
  {"ruleName":"start-every-day"}
  EOF
}

module "cloudwatch_ec2_stop" {
  source = "./modules/cloudwatch"

  # Rule
  cw_event_rule_name        = "stop-every-day-tf"
  cw_event_rule_description = "Fires every weekday after business hours. GMT based. Region's time zone should be considered."
  cw_event_rule_schedule    = "cron(30 9 ? * MON-FRI *)"

  # Target
  target_arn   = module.ec2_start_stop_lambda.lambda_arn
  target_input = <<EOF
  {"ruleName":"stop-every-day"}
  EOF
}
