resource "aws_sqs_queue" "bucket_notifications" {
  name = local.naming_prefix
  visibility_timeout_seconds = var.event_processing_timeout + 5
}

resource "aws_sqs_queue_policy" "bucket_notifications" {
  queue_url = aws_sqs_queue.bucket_notifications.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.bucket_notifications.arn}",
      "Condition": {
        "ArnEquals": { "aws:SourceArn": "${var.cloudtrail_bucket.arn}" }
      }
    }
  ]
}
POLICY
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.cloudtrail_bucket.name

  queue {
    queue_arn = aws_sqs_queue.bucket_notifications.arn
    events    = ["s3:ObjectCreated:*"]
    filter_suffix = ".json.gz"
  }

  depends_on = [
    aws_sqs_queue_policy.bucket_notifications
  ]
}