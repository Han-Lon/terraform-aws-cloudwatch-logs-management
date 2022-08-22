variable "aws-partition" {
  description = "The specific AWS partition to be deployed into. Vast majority of use cases will only need the regular 'aws' partition."
  default = "aws"

  validation {
    condition = can(regex("aws|aws-us-gov|aws-cn", var.aws-partition))
    error_message = "Please use a valid AWS partition, or comment out this validation check if the provided list is out of date."
  }
}

data "aws_caller_identity" "current-account" {
  # To retrieve the account ID -- needed for KMS key policy
}

data "aws_region" "current-region" {
  # To retrieve the current AWS region
}

resource "aws_kms_key" "log-encryption-key" {
  description = "Key for CloudWatch log encryption"
  deletion_window_in_days = 7
  # Avoiding dynamic references to resources (especially the module object) to avoid circular dependencies with the key policy
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Id": "key-consolepolicy",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:${var.aws-partition}:iam::${data.aws_caller_identity.current-account.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
          "Sid": "Allow use of the key for Lambda IAM role",
          "Effect": "Allow",
          "Principal": {"AWS": [
            "arn:${var.aws-partition}:iam::${data.aws_caller_identity.current-account.account_id}:role/terraform-cloudwatch-log-management-lambda-role"
          ]},
          "Action": [
            "kms:DescribeKey"
          ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "logs.${data.aws_region.current-region.name}.amazonaws.com"
            },
            "Action": [
                "kms:Encrypt*",
                "kms:Decrypt*",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:Describe*"
            ],
            "Resource": "*",
            "Condition": {
                "ArnEquals": {
                    "kms:EncryptionContext:${var.aws-partition}:logs:arn": "arn:${var.aws-partition}:logs:${data.aws_region.current-region.name}:${data.aws_caller_identity.current-account.account_id}:*:*"
                }
            }
        }
    ]
}
EOF
}

resource "aws_kms_alias" "log-encryption-key-alias" {
  target_key_id = aws_kms_key.log-encryption-key.key_id
  name          = "alias/log-encryption-key" # Must be the same as the kms_key_alias variable passed to the module below
}

module "log-management-automation" {
  source = "../.." # Replace with "Han-Lon/cloudwatch-logs-management/aws" in your own code

  # Lambda will execute once every two days. It will enforce a retention policy of 7 days on all log groups and
  # KMS encryption using the KMS key with alias "log-encryption-key"
  invocation_rate   = "rate(2 days)"
  retention_in_days = "7"
  kms_key_alias     = "log-encryption-key"

  depends_on = [aws_kms_key.log-encryption-key]
}