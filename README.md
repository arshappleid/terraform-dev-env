# Terraform Env with Cloud Cli tools
This project is a template to use for terraform Projects, which comes with AWS Cli tools preinstalled. Installation of the cli tools can can configured from the Docker compose files. Additionally tools for terraform linting (TFLint) and Terraform Security have been pre installed. Additionally this project has been configured with VSCode Extensions to lint and run the security config check on each 

This project ensures that AWS/Azure Credentials for different projects remain contained within the Docker environment. Which mitigates the risk of accidentally deploying into an unknown account. Although requires configuring the account logins through single-sign on on each new project. 

Tested on : Apple M1 Architecture. AWS Cli Install command is Diff for X86-64 [Read Here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Benefits
1. Setup new environments for new project by just cloning the repo.
2. Easily install AWS/Azure Cli tools. Also comes pre installed with linting and security config checking tools
3. Easily manage login credentials within directories, rather than having to worry about managing through x

## Requirements
1. Docker, Docker compose. 
2. VsCode IDE, [Run on Save Extension](https://marketplace.visualstudio.com/items?itemName=emeraldwalk.RunOnSave)

## Setting up the Environment
Ensure docker, docker compose , and the docker engine is installed.
```
brew install -y docker ## MacOS
```

### Spin up the container
```
docker compose up -d
docker ps ## Take the container ID
docker exec --interactive --tty <container_id> bash
```

### Inside the Container
```
az version
aws --version

terraform init ## install all modules
terraform apply ## Deploy everything
terraform apply --auto-approve
terraform destroy

## Configure Subscription 
az account list --output table
az account set --subscription "<subscription-id-or-name>"
az account show --output table
az account list --output table ## use this to get the subscription id

## AWS Configure Login
aws login --remote
```

### Managing different Environments

1. Create different Accounts (dev,stage, prod) in AWS accounts.
2. Configure the account ARN`s in the locals variable, and inject into provider block. 
```
locals {
  # Replace these ARNs with your actual Role ARNs for Dev and Prod
  account_role_arns = {
    default = "arn:aws:iam::123456789012:role/DevRole" # Optional fallback
    dev     = "arn:aws:iam::111111111111:role/OrganizationAccountAccessRole"
    prod    = "arn:aws:iam::222222222222:role/OrganizationAccountAccessRole"
  }
  # Safety check: Determine the ARN based on the current workspace
  # If the workspace isn't in the map, this will fail (which prevents accidental deploys)
  current_role_arn = local.account_role_arns[terraform.workspace]
}
provider "aws" {
  region = var.region

  # This block dynamically switches accounts
  assume_role {
    role_arn = local.current_role_arn
  }
}
```
3. Manage Terraform Workspace
```
terraform workspace new dev
terraform workspace new prod
terraform workspace select dev
```

## Running Linting and Security Config Checker
Both the [Terraform Lint](https://github.com/terraform-linters/tflint) and [TFSec](https://aquasecurity.github.io/tfsec/v1.20.0/guides/usage/) are configured to run on file saves, and the output is shown in the Output section of the terminal. 
