# 🚀 EC2 Instance Scheduler – Automated Start/Stop with AWS Lambda & Terraform

## 📌 Overview
This project deploys an **AWS Lambda function** that **automatically starts and stops EC2 instances** based on a custom schedule defined in a **`KeepOn`** tag.  
It’s built for cost optimization and convenience — you decide when your instances should run, and Lambda enforces it, every hour, like clockwork. ⏰

The entire deployment is **automated with Terraform**, so in just one command you can:
- Create the IAM role and permissions
- Package and deploy the Lambda function (with Python dependencies)
- Set up a CloudWatch Event Rule to trigger the Lambda hourly
- Configure log retention and resource tagging for best practices

---

## ✨ Features
- **📅 Tag-Based Scheduling** – Control EC2 uptime with a tag like:

KeepOn = Mo+Tu+We+Th+Fr:08-19

Example: Run Monday–Friday, 8 AM–7 PM (Eastern Time).

- **🌎 Timezone Aware** – Uses **US/Eastern** timezone for scheduling.

- **🔄 Fully Automated Deployment** – Terraform builds, zips, and uploads the Lambda along with required dependencies (`pytz`).

- **💰 Cost Savings** – Automatically stops unused EC2 instances outside working hours.

- **🛡️ Least Privilege IAM** – Lambda only gets the EC2 permissions it needs.

- **📜 Log Retention** – CloudWatch logs are automatically cleaned up after a configurable retention period.

- **🏷️ Tagging** – All resources are tagged for easy cost tracking and management.

---

## 🗂 Directory Structure

.
├── main.tf # Terraform infrastructure code
├── lambda_function.py # Lambda function code
├── requirements.txt # Python dependencies (pytz)


---

## ⚙️ How It Works
1. Lambda runs every hour via **CloudWatch Event Rule**.
2. It checks the current Eastern Time day & hour.
3. Reads the `KeepOn` tag from EC2 instances.
4. If the current time matches the schedule:
   - **Starts** stopped instances at `start_hour`
   - **Stops** running instances at `end_hour`
5. Logs every decision for auditing.

---

## 🏗 Deployment Guide

### 1️⃣ Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- AWS credentials configured (`~/.aws/credentials` or environment variables)
- Python 3.9+ installed (for dependency packaging)

---

### 2️⃣ Setup
Clone the repository and add your Lambda function code to `lambda_function.py` (your scheduling script).

Dependencies go into `requirements.txt`:
```txt
pytz

3️⃣ Deploy

terraform init
terraform apply

Terraform will:
Create the IAM role & policies
Install dependencies into a build folder
Zip and upload the Lambda function
Create the CloudWatch Event Rule & permissions
Set up CloudWatch Log Group with retention

4️⃣ Configure Instance Tags
Add the KeepOn tag to your EC2 instances.
Format: <Day+Day+...>:<StartHour>-<EndHour>

Days: Mo, Tu, We, Th, Fr, Sa, Su
Hours: 24-hour format (Eastern Time)

KeepOn = Mo+We+Fr:09-17

➡ Runs on Monday, Wednesday, and Friday from 9 AM to 5 PM EST.

📡 CloudWatch Schedule
This setup uses: cron(0 * * * ? *)

Which means run at the start of every hour.

🛠 Customization
Change Log Retention
Edit main.tf:
variable "log_retention_days" {
  default = 30
}


Change AWS Region
provider "aws" {
  region = "us-east-1"
}


🧹 Cleanup
To remove all resources:
terraform destroy

📋 Example Terraform Output
When applied successfully:

aws_lambda_function.ec2_scheduler: Creation complete
aws_cloudwatch_event_rule.hourly: Creation complete
aws_cloudwatch_event_target.run_ec2_scheduler: Creation complete
aws_lambda_permission.allow_eventbridge: Creation complete

Apply complete! Resources: 7 added, 0 changed, 0 destroyed.




