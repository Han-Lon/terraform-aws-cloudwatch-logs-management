import boto3
import os
import traceback


def retrieve_region_log_groups(cw):
    """
    Retrieve all CloudWatch log groups in a region
    :param cw: CloudWatch Logs boto3 client object
    :return: region_log_groups as a list of dicts containing log group data
    """
    log_groups_response = cw.describe_log_groups()
    try:
        region_log_groups = log_groups_response['logGroups']
    except Exception as e:
        print(f"Ran into error when retrieving log groups for {cw.meta.region_name} region")
        print(traceback.format_exc())
    while 'nextToken' in log_groups_response:
        log_groups_response = cw.describe_log_groups(nextToken=log_groups_response['nextToken'])
        region_log_groups.extend(log_groups_response['logGroups'])
    return region_log_groups


def retrieve_kms_key_id():
    """
    Retrieve the KMS key ID using the KMS alias of the key in the account
    :return:
    """
    kms = boto3.client("kms")
    try:
        key_info = kms.describe_key(
            KeyId=f'alias/{os.environ["KMS_KEY_ALIAS"]}'
        )
    except Exception as e:
        print(f"Ran into error during KMS key retrieval for {kms.meta.region_name}")
        print(traceback.format_exc())
    return key_info['KeyMetadata']['Arn']


def configure_log_groups(cw, log_groups):
    """
    Configure all log groups in an AWS region with the desired configuration settings
    :param cw: CloudWatch Logs boto3 client object
    :param log_groups: A list of dicts containing log group data, received from retrieve_region_log_groups()
    """
    # TODO error handling, especially for KMS bullshit
    print(f">>> Configuring log groups for {cw.meta.region_name} <<<")

    if os.environ.get("KMS_KEY_ALIAS", "None") != "None":
        print(">>> KMS_KEY_ALIAS environment variable set-- retrieving key ID <<<")
        key_id = retrieve_kms_key_id()

    for log_group in log_groups:
        if os.environ.get("KMS_KEY_ALIAS", "None") != "None":
            try:
                cw.associate_kms_key(
                    logGroupName=log_group['logGroupName'],
                    kmsKeyId=key_id
                )
            except Exception as e:
                print(f"Ran into error when encrypting log group {log_group['logGroupName']} in {cw.meta.region_name}")
                print(traceback.format_exc())
        if os.environ.get("RETENTION_IN_DAYS", "None") != "None":
            try:
                cw.put_retention_policy(
                   logGroupName=log_group['logGroupName'],
                   retentionInDays=int(os.environ['RETENTION_IN_DAYS'])
                )
            except Exception as e:
                print(f"Ran into error when attaching retention policy to log group {log_group['logGroupName']} in {cw.meta.region_name}")
                print(traceback.format_exc())
    print(f">>> Done configuring log groups for {cw.meta.region_name} <<<")


def lambda_handler(event, context):
    print(">>> START EXECUTION <<<")
    regions = os.environ.get("CROSS_REGIONS", None)

    print(">>> Instantiate Cloudwatch Logs client in current region <<<")
    cw = boto3.client("logs")
    configure_log_groups(cw, retrieve_region_log_groups(cw))

    # Determine if multi-region is desired
    if "," in regions:
        # More than 1 extra region
        regions = regions.split(",")
    elif regions != "None":
        # 1 extra region (besides default), but no more
        regions = [regions]
    else:
        # just the account we've deployed into
        return True

    for region in regions:
        print(f">>> Instantiating CloudWatch Logs client in {region} region <<<")
        cw = boto3.client("logs", region_name=region)
        configure_log_groups(cw, retrieve_region_log_groups(cw))

    print(">>> END EXECUTION <<<")
    return True

