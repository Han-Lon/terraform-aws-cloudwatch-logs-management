# Create the IAM role that the log_management
resource "aws_iam_role" "log-management-lambda-role" {
  name = "${local.project}-lambda-role"

  assume_role_policy = <<EOF
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

# Minimum required IAM policy for the log management automation
data "aws_iam_policy_document" "log-management-policy-doc" {
  statement {
    sid = "LogManagement"
    actions = [
      "logs:AssociateKmsKey",
      "logs:DescribeLogGroups",
      "logs:DisassociateKmsKey",
      "logs:ListTagsLogGroup",
      "logs:PutRetentionPolicy"
    ]
    resources = [
      "*"
    ]
    effect = "Allow"
  }

  statement {
    sid = "SelfLoggingAccess"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/terraform-cloudwatch-log-management-lambda:log-stream:*",
      "arn:aws:logs:*:*:log-group:/aws/lambda/terraform-cloudwatch-log-management-lambda"
    ]
  }
}

# IAM policy required for KMS key encryption of log groups by the log management automation
data "aws_iam_policy_document" "log-management-encryption-doc" {
  count = var.kms_key_alias != "None" ? 1 : 0
  # Only way to make this work cross-region with multiple different key IDs.
  # Scoped down to ONLY the necessary KMS key(s) by using a conditional with the alias
  statement {
    sid = "AllowDescribeKey"
    actions = [
      "kms:DescribeKey"
    ]
    resources = ["*"]
    # See the below doc for where this conditional comes from
    # https://docs.aws.amazon.com/kms/latest/developerguide/policy-conditions.html#conditions-kms-request-alias
    condition {
      test     = "StringEquals"
      values   = [var.kms_key_alias]
      variable = "kms:RequestAlias"
    }
  }
}

# Combine the two above IAM policies if needed (not needed if we aren't doing KMS key encryption)
data "aws_iam_policy_document" "log-management-policies-combined" {
  count = var.kms_key_alias != "None" ? 1 : 0
  source_policy_documents = [
    data.aws_iam_policy_document.log-management-policy-doc.json,
    data.aws_iam_policy_document.log-management-encryption-doc[0].json
  ]
}

# Create the actual IAM policy (the above are just IAM policy data objects in Terraform)
resource "aws_iam_policy" "log-management-lambda-policy" {
  name   = "${local.project}-lambda-policy"
  policy = var.kms_key_alias != "None" ? data.aws_iam_policy_document.log-management-policies-combined[0].json : data.aws_iam_policy_document.log-management-policy-doc.json
}

# Attach the above IAM policy to the IAM role
resource "aws_iam_role_policy_attachment" "log-management-role-attach1" {
  role       = aws_iam_role.log-management-lambda-role.name
  policy_arn = aws_iam_policy.log-management-lambda-policy.arn
}