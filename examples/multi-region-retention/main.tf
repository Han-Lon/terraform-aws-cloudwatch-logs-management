provider "aws" {
  region = "us-east-1"  # Default to us-east-1 for this demo, can change to anything else as long as it isn't in the cross_regions variable below
}

module "log-management-automation" {
  source = "../.."  # Replace with "Han-Lon/cloudwatch-logs-management/aws" in your own code

  # Lambda will execute once every day. It will enforce a retention policy of 14 days on all log groups in the
  # deployed region, us-west-1, and us-west-2
  invocation_rate   = "rate(1 day)"
  retention_in_days = "14"
  cross_regions = "us-west-1,us-west-2"  # Notice how we do NOT specify the deployed region (us-east-1 in this demo)
}