# Overview

This Terraform code deploys an AWS Lambda function to start and stop instances tagged with {"Key": "Shutdown", "Value": "true"} at given times.

## How does this work?

The Terraform code deploys a Python 3.7 AWS Lambda function, AWS CloudWatch rules as well as required permissions and roles. The CloudWatch rules trigger the Lambda function at schedulled times which scans the instances for the {"Key": "Shutdown", "Value": "true"} tag and either stops or starts the tagged instances.

## Deployment

### Prerequisites/Considerations

The following should be considered when deploying first time:

* The AWS CLI should be installed.
* AWS credentials configured locally. Terraform should be able to obtain the credentials to access the AWS account (e.g. from environmental variables, secrets manager, AWS CLI configuration etc.). As a test you can run `aws s3 ls` to check if the AWS CLI configured properly.
* The backend S3 bucket, key and DynamoDB lock table should be created/configured (see the `e2-start-stop-lambda/main.tf` file).
* Resource names, the availability zone, `cron` schedules can also be adjusted to your needs.

### Terraform

Follow the below steps to deploy the script:

* Clone the repository
* Install Terraform (the code was tested using Terraform v0.14.5)
* Run the commands:

```shell
cd ec2-start-stop-lambda
terraform init
terraform plan
terraform apply
```

### Bitbucket Pipelines (sandbox account)

Merge a feature branch into master.

## Who do I talk to?

Cloud Enablement Team
