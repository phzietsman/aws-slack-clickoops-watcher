#  _____   ___ _____  ______ ___________ ___  _   _ _    _____ _____ 
# /  __ \ / _ \_   _| |  _  \  ___|  ___/ _ \| | | | |  |_   _/  ___|
# | /  \// /_\ \| |   | | | | |__ | |_ / /_\ \ | | | |    | | \ `--. 
# | |    |  _  || |   | | | |  __||  _||  _  | | | | |    | |  `--. \
# | \__/\| | | || |   | |/ /| |___| |  | | | | |_| | |____| | /\__/ /
#  \____/\_| |_/\_/   |___/ \____/\_|  \_| |_/\___/\_____/\_/ \____/ 
# 
# https://patorjk.com/software/taag/#p=display&f=Doom&t=DEFAULTS
#
# 

variable "region" {
  type        = string
  description = "The default region for the application / deployment"

  validation {
    condition = contains([
      "eu-central-1",
      "eu-west-1",
      "eu-west-2",
      "eu-south-1",
      "eu-west-3",
      "eu-north-1",
      "af-south-1"
    ], var.region)
    error_message = "Invalid region provided."
  }
}

variable "environment" {
  type        = string
  description = "Will this deploy a development (dev) or production (prod) environment"

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "Stage must be either 'dev' or 'prd'."
  }
}

variable "code_repo" {
  type        = string
  description = "Points to the source code used to deploy the resources {{repo}} [{{branch}}]"
}

variable "namespace" {
  type        = string
  description = "Used to identify which part of the application these resources belong to (auth, infra, api, web, data)"

  validation {
    condition     = contains(["auth", "infra", "api", "web", "data"], var.namespace)
    error_message = "Namespace needs to be : \"auth\", \"infra\", \"api\" or \"web\"."
  }
}

variable "application_name" {
  type = object({
    short = string
    long  = string
  })
  description = "Used in naming conventions, expecting an object"

  validation {
    condition     = length(var.application_name["short"]) <= 5
    error_message = "The application_name[\"short\"] needs to be less or equal to 5 chars."
  }
}

variable "nukeable" {
  type        = bool
  description = "Can these resources be cleaned up. Will be ignored for prod environments"
}

variable "client_name" {
  type = object({
    short = string
    long  = string
  })
  description = "Used in naming conventions, expecting an object"

  validation {
    condition     = length(var.client_name["short"]) <= 5
    error_message = "The client_name[\"short\"] needs to be less or equal to 5 chars."
  }
}

variable "purpose" {
  type        = string
  description = "Used for cost allocation purposes"

  validation {
    condition     = contains(["rnd", "client", "product"], var.purpose)
    error_message = "Purpose needs to be : \"rnd\", \"client\", \"product\"."
  }
}

variable "owner" {
  type        = string
  description = "Used to find resources owners, expects an email address"

  validation {
    condition     = can(regex("^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$", var.owner))
    error_message = "Owner needs to be a valid email address."
  }
}

variable "aws_account_id" {
  type        = string
  description = "Needed for Guards to ensure code is being deployed to the correct account"
}

variable "tags" {
  type        = map(string)
  description = "Default tags added to all resources, this will be added to the provider"
}

#  _____ _   _  ___  __________________  ___  _____ _      _____ 
# |  __ \ | | |/ _ \ | ___ \  _  \ ___ \/ _ \|_   _| |    /  ___|
# | |  \/ | | / /_\ \| |_/ / | | | |_/ / /_\ \ | | | |    \ `--. 
# | | __| | | |  _  ||    /| | | |    /|  _  | | | | |     `--. \
# | |_\ \ |_| | | | || |\ \| |/ /| |\ \| | | |_| |_| |____/\__/ /
#  \____/\___/\_| |_/\_| \_|___/ \_| \_\_| |_/\___/\_____/\____/ 
# 
# These will raise errors when the conditions are not met

data "aws_caller_identity" "current" {
  provider = aws.reference
}


resource "null_resource" "tf_guard_provider_account_match" {
  count = tonumber(data.aws_caller_identity.current.account_id == var.aws_account_id ? "1" : "fail")
}

#  _   _   ___  ___  ________ _   _ _____ 
# | \ | | / _ \ |  \/  |_   _| \ | |  __ \
# |  \| |/ /_\ \| .  . | | | |  \| | |  \/
# | . ` ||  _  || |\/| | | | | . ` | | __ 
# | |\  || | | || |  | |_| |_| |\  | |_\ \
# \_| \_/\_| |_/\_|  |_/\___/\_| \_/\____/
#
# 

locals {
  mandatory_tags = merge(var.tags, {
    "cat:application" = var.application_name.long
    "cat:client"      = var.client_name.long
    "cat:purpose"     = var.purpose
    "cat:owner"       = var.owner
    "cat:repo"        = var.code_repo
    "cat:nukeable"    = var.nukeable

    "tf:account_id" = data.aws_caller_identity.current.account_id
    "tf:caller_arn" = data.aws_caller_identity.current.arn
    "tf:user_id"    = data.aws_caller_identity.current.user_id

    "app:region"      = var.region
    "app:namespace"   = var.namespace
    "app:environment" = var.environment
  })

  naming_prefix = join("-", [
    var.client_name.short,
    var.application_name.short,
    var.environment,
    var.namespace
  ])
}


#  _____ _   _ ___________ _   _ _____ 
# |  _  | | | |_   _| ___ \ | | |_   _|
# | | | | | | | | | | |_/ / | | | | |  
# | | | | | | | | | |  __/| | | | | |  
# \ \_/ / |_| | | | | |   | |_| | | |  
#  \___/ \___/  \_/ \_|    \___/  \_/  
# 
# We use various IaC tools and have found SSM Parameters
# a great way to share the output values between systems

locals {
  outputs = {}
}

resource "aws_ssm_parameter" "outputs" {

  for_each = local.outputs

  name        = "/${local.naming_prefix}/tf-output/${each.key}"
  description = "Give other systems a handle on this code's outputs"

  type   = each.value["secure"] ? "SecureString" : "String"
  key_id = var.kms_key_other

  value = jsonencode(each.value["value"])

  tags = merge(local.mandatory_tags, {
    Name = "${local.naming_prefix}-output-${each.key}"
  })
}