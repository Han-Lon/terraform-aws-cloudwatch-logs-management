data "aws_caller_identity" "current-account" {
  # To retrieve the account ID -- needed for KMS key policy
}

data "aws_region" "current-region" {
  # To retrieve the current AWS region
}

resource "aws_kms_key" "log-encryption-key" {
  description = "Key for CloudWatch log encryption"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Id": "key-consolepolicy",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${data.aws_caller_identity.current-account.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
          "Sid": "Allow use of the key for Lambda IAM role",
          "Effect": "Allow",
          "Principal": {"AWS": [
            "${module.log-management-automation.lambda-iam-role-arn}"
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
                    "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:${data.aws_region.current-region.name}:${data.aws_caller_identity.current-account.account_id}:*:*"
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
}