resource "aws_iam_role" "lambda" {
  name = local.naming_prefix

  assume_role_policy = data.aws_iam_policy_document.lambda_role_trust.json
}

data "aws_iam_policy_document" "lambda_role_trust" {
  statement {
    sid = "LambdaTrust"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = local.naming_prefix
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}


data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid = "Logging"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }

  statement {
    sid = "S3Access"

    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:Describe*",
    ]

    resources = [
      "${var.cloudtrail_bucket.arn}/",
      "${var.cloudtrail_bucket.arn}/*",
    ]
  }

  statement {
    sid = "SSMAccess"

    actions = [
      "ssm:Get*",
    ]

    resources = [
      aws_ssm_parameter.slack_webhook.arn
    ]
  }

  statement {
    sid = "SQSAccess"

    actions = [
      "sqs:*",
    ]

    resources = [
      aws_sqs_queue.bucket_notifications.arn
    ]
  }

}