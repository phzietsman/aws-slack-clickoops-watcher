**NOTE** Standalone terraform module [here](https://github.com/cloudandthings/terraform-aws-clickops-notifier)

# AWS ClickOops watcher for Slack
This deployment allows you to monitor your AWS accounts for changes being made in the console.

## Prerequisites
1. The solution has been built to be used in an AWS multi-account environment provisioned using [AWS Control Tower](https://aws.amazon.com/controltower). In Control Tower all CloudTrail logs are shipped to a central Log Archive account which simplifies the processing of these logs.

2. Additionally you will need a [Slack app](https://api.slack.com/apps)  with an incoming webhook configured.

## Post deployment
After deploying the solution you will need to set the SSM parameter containing the Slack Webhook URL manually. This is not set in code for security reasons.

## Terraform
### Requirements

| Name | Version |
|------|---------|
| aws | 3.49.0 |

### Providers

| Name | Version |
|------|---------|
| archive | n/a |
| aws | 3.49.0 |
| aws.reference | 3.49.0 |
| null | n/a |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| application\_name | Used in naming conventions, expecting an object | <pre>object({<br>    short = string<br>    long  = string<br>  })</pre> | n/a | yes |
| aws\_account\_id | Needed for Guards to ensure code is being deployed to the correct account | `string` | n/a | yes |
| client\_name | Used in naming conventions, expecting an object | <pre>object({<br>    short = string<br>    long  = string<br>  })</pre> | n/a | yes |
| cloudtrail\_bucket | Bucket containing the Cloudtrail logs that you want to process. | <pre>object({<br>    name   = string<br>    arn    = string<br>  })</pre> | n/a | yes |
| code\_repo | Points to the source code used to deploy the resources {{repo}} [{{branch}}] | `string` | n/a | yes |
| environment | Will this deploy a development (dev) or production (prod) environment | `string` | n/a | yes |
| event\_processing\_timeout | Maximum number of seconds the lambda is allowed to run and number of seconds events should be hidden in SQS after being picked up my Lambda. | `number` | `60` | no |
| excluded\_accounts | List of accounts that be excluded for scans on manual actions. | `list(string)` | `[]` | no |
| included\_accounts | List of accounts that be scanned to manual actions. | `list(string)` | `[]` | no |
| log\_retention\_in\_days | Number of days to keep CloudWatch logs | `number` | `30` | no |
| namespace | Used to identify which part of the application these resources belong to (auth, infra, api, web, data) | `string` | n/a | yes |
| nukeable | Can these resources be cleaned up. Will be ignored for prod environments | `bool` | n/a | yes |
| owner | Used to find resources owners, expects an email address | `string` | n/a | yes |
| purpose | Used for cost allocation purposes | `string` | n/a | yes |
| region | The default region for the application / deployment | `string` | n/a | yes |
| tags | Tags added to all resources, this will be added to the list of mandatory tags | `map(string)` | n/a | yes |

### Sample terraform.tfvars

```hcl
cloudtrail_bucket = {
  name          = "aws-controltower-logs-XXX-eu-west-1"
  arn           = "arn:aws:s3:::aws-controltower-logs-XXX-eu-west-1"
}

region           = "eu-west-1"
environment      = "prd"
code_repo        = "github.com:phzietsman/aws-slack-clickoops-watcher"
namespace        = "sec"
application_name = { short : "clkop", long : "clickoops" }
nukeable         = false
client_name      = { short : "cat", long : "cloudandthings" }
purpose          = "self"
owner            = "paul@cloudandthings.io"
aws_account_id   = "xxx"
tags = {
  "description" : "Part of the solution to check whether we are using the AWS Console to manage our resourcese."
}
```
## Credits
https://arkadiyt.com/2019/11/12/detecting-manual-aws-console-actions/

https://towardsdatascience.com/protect-your-infrastructure-with-real-time-notifications-of-aws-console-user-changes-3144fd18c680
