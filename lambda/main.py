import json
import urllib.parse
import urllib.request
import boto3
import io
import gzip
import re
import os
from botocore.vendored import requests

s3 = boto3.client('s3')
ssm = boto3.client('ssm')

USER_AGENTS = {
    "console.amazonaws.com", 
    "Coral/Jakarta", 
    "Coral/Netty4"
}
USER_AGENTS_RE = [
    "signin.amazonaws.com(.*)",
    "^S3Console",
    "^\[S3Console",
    "^Mozilla/",
    "^console(.*)amazonaws.com(.*)",
    "^aws-internal(.*)AWSLambdaConsole(.*)",
]
IGNORED_EVENTS = {
    "DownloadDBLogFilePortion", 
    "TestScheduleExpression", 
    "TestEventPattern", 
    "LookupEvents",
    "listDnssec", 
    "Decrypt",
    "REST.GET.OBJECT_LOCK_CONFIGURATION", 
    "ConsoleLogin"
}
IGNORED_SCOPED_EVENTS = [
    "cognito-idp.amazonaws.com:InitiateAuth",
    "cognito-idp.amazonaws.com:RespondToAuthChallenge",
    
    "sso.amazonaws.com:Federate",
    "sso.amazonaws.com:Authenticate",
    "sso.amazonaws.com:Logout",
    "sso.amazonaws.com:SearchUsers",
    "sso.amazonaws.com:SearchGroups",
    
    "signin.amazonaws.com:UserAuthentication",
    "signin.amazonaws.com:SwitchRole",
    "signin.amazonaws.com:RenewRole",
    "signin.amazonaws.com:ExternalIdPDirectoryLogin",
    
    "logs.amazonaws.com:StartQuery",
    
    "iam.amazonaws.com:SimulatePrincipalPolicy",
    "iam.amazonaws.com:GenerateServiceLastAccessedDetails",

    "glue.amazonaws.com:BatchGetJobs",
    "glue.amazonaws.com:BatchGetCrawlers",
    "glue.amazonaws.com:StartJobRun",
    "glue.amazonaws.com:StartCrawler",

    "servicecatalog.amazonaws.com:SearchProductsAsAdmin",
    "servicecatalog.amazonaws.com:SearchProducts",
    "servicecatalog.amazonaws.com:SearchProvisionedProducts",
    "servicecatalog.amazonaws.com:TerminateProvisionedProduct",

    "cloudshell.amazonaws.com:CreateSession",
    "cloudshell.amazonaws.com:PutCredentials",
    "cloudshell.amazonaws.com:SendHeartBeat",
    "cloudshell.amazonaws.com:CreateEnvironment"
]
READONLY_EVENTS_RE = [
    "^Get",
    "^Describe",
    "^List",
    "^Head",
]

WEBHOOK_PARAMETER = os.environ['WEBHOOK_PARAMETER']
EXCLUDED_ACCOUNTS = json.loads(os.environ['EXCLUDED_ACCOUNTS'])
INCLUDED_ACCOUNTS = json.loads(os.environ['INCLUDED_ACCOUNTS'])

WEBHOOK_URL = None

def get_wekbhook() -> str:
    global WEBHOOK_URL
    if WEBHOOK_URL is None:
        response = ssm.get_parameter(Name=WEBHOOK_PARAMETER, WithDecryption=True)
        WEBHOOK_URL = response['Parameter']['Value']

    return WEBHOOK_URL

def send_slack_message(user, event, s3_bucket, s3_key, webhook) -> bool:
    slack_payload = {
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": ":bell: ClickOps Alert :bell:",
                    "emoji": True
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "Someone is practicing ClickOps in your AWS Account!"
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*Account Id*\n{event['recipientAccountId']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Region*\n{event['awsRegion']}"
                    }
                ]
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*IAM Action*\n{event['eventSource'].split('.')[0]}:{event['eventName']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Principle*\n{user}"
                    }
                ]
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*Cloudtrail Bucket*\n{s3_bucket}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Key*\n{s3_key}"
                    }
                ]
            },
            {
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Event*\n```{json.dumps(event, indent=2)}```"
                }
            },
        ]
    }

    response = requests.post(webhook, json=slack_payload)
    if response.status_code != 200:
        return False
    return True

def valid_account(key) -> bool:
    if len(EXCLUDED_ACCOUNTS) == 0 and len(INCLUDED_ACCOUNTS) == 0:
        return True
    
    if any(acc for acc in EXCLUDED_ACCOUNTS if acc in key ):
        print(f'{key} in {json.dumps(EXCLUDED_ACCOUNTS)}')
        return False
    
    if len(INCLUDED_ACCOUNTS) == 0:
        return True
    
    if any(acc for acc in INCLUDED_ACCOUNTS if acc in key):
        return True
        
    print(f'{key} not in {json.dumps(INCLUDED_ACCOUNTS)}')
    return False

def check_regex(expr, txt) -> bool:
    match = re.search(expr, txt)
    return match is not None

def match_user_agent(txt) -> bool:
    if txt in USER_AGENTS:
        return True

    for expresion in USER_AGENTS_RE:
        if check_regex(expresion, txt):
            return True

    return False

def match_readonly_event(event) ->bool:
    if 'readOnly' in event:
        if event['readOnly'] == 'true' or event['readOnly'] == True:
            return True
        else:
            return False
    else:
        return False

def match_readonly_event_name(txt) -> bool:
    for expression in READONLY_EVENTS_RE:
        if check_regex(expression, txt):
            return True

    return False

def match_ignored_events(event_name) -> bool:
    return event_name in IGNORED_EVENTS

def match_ignored_scoped_events(event_name, event_source) -> bool:
    return f'{event_source}:{event_name}' in IGNORED_SCOPED_EVENTS

def filter_user_events(event) -> bool:
    is_match = match_user_agent(event['userAgent'])
    is_readonly_event = match_readonly_event(event)
    is_readonly_action = match_readonly_event_name(event['eventName'])
    is_ignored_event = match_ignored_events(event['eventName'])
    is_ignored_scoped_event = match_ignored_scoped_events(event['eventName'], event['eventSource'], )
    is_in_event = 'invokedBy' in event['userIdentity'] and event['userIdentity']['invokedBy'] == 'AWS Internal'

    info = {
        'is_match': is_match,
        'is_readonly_event': is_readonly_event,
        'is_readonly_action': is_readonly_action,
        'is_ignored_event': is_ignored_event,
        'is_ignored_scoped_event': is_ignored_scoped_event,
        'is_in_event': is_in_event
    }

    print("--- filter_user_events output ---")
    print(json.dumps(event))
    print(json.dumps(info))
    
    status = is_match and not is_readonly_event and not is_readonly_action and not is_ignored_event and not is_in_event and not is_ignored_scoped_event

    return status


def get_user_email(principal_id) -> str:
    words = principal_id.split(':')
    if len(words) > 1:
        return words[1]
    return principal_id


"""
This functions processes CloudTrail logs from S3, filters events from the AWS Console, and publishes to SNS
:param event: List of S3 Events
:param context: AWS Lambda Context Object
:return: None
"""
def handler(event, context) -> None:

    # print("--- SQS EVENT ---")
    # print(json.dumps(event))

    webhook_url = get_wekbhook()

    for sqs_record in event['Records']:
        s3_events = json.loads(sqs_record['body'])

        # print("--- Bucket EVENT ---")
        # print(json.dumps(s3_events))

        records = s3_events.get("Records", [])

        for record in records:

            # Get the object from the event and show its content type
            bucket = record['s3']['bucket']['name']
            key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')

            key_elements = key.split("/")
            if "CloudTrail" not in key_elements:
                continue

            # print("--- CloudTrail Event ---")
            # print(json.dumps(record))

            if not valid_account(key):
                continue

            try:
                response = s3.get_object(Bucket=bucket, Key=key)
                content = response['Body'].read()

                with gzip.GzipFile(fileobj=io.BytesIO(content), mode='rb') as fh:
                    event_json = json.load(fh)
                    output_dict = [record for record in event_json['Records'] if filter_user_events(record)]
                    for item in output_dict:
                        user = get_user_email(item['userIdentity']['principalId'])
                        if not send_slack_message(user, item, s3_bucket=bucket, s3_key=key, webhook=webhook_url):
                            print("[ERROR] Slack Message not sent")
                            print(json.dumps(item))
                # return response['ContentType']
            except Exception as e:
                print(e)
                message = f"""
                    Error getting object {key} from bucket {bucket}.
                    Make sure they exist and your bucket is in the same region as this function.
                """
                print(message)
                raise e
    
    return "Completed"
