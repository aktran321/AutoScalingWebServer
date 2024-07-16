# AutoScalingWebServer

## Description

This project demonstrates the creation of a highly available web server architecture using Terraform. The architecture is designed to ensure high availability while minimizing costs. Key features include automated scaling based on CPU usage and detailed network configuration.

## Features

- **Highly Available Architecture**: Ensures web servers remain available even during peak loads or hardware failures.
- **Auto Scaling**: Configured CloudWatch alarms to trigger an Auto Scaling Group to scale in and out based on CPU usage.
- **Testing**: Simulated high CPU usage with a Linux user data script to test the alarms and auto-scaling configuration.
- **Network Configuration**: In-depth configuration of subnets, security groups, NAT Gateway, and Internet Gateway.

## Prerequisites

- **Terraform**: Ensure you have Terraform installed on your local machine.
- **AWS Account**: An AWS account with necessary permissions to create and manage resources.
- **AWS CLI**: Installed and configured with your AWS credentials.

## Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/yourusername/your-repo.git
   cd your-repo
   ```
2. **Terraform Commands**

```
terraform init
terraform plan
terraform apply
```

When the architecture is completed, you will have a new VPC with a load balancer in the publib subnet and an ASG in the private subnet. An EC2 instance is created with a User Data script. The script will simulate high CPU usage on teh instance, triggering a CloudWatch alarm, which then notifies teh ASG to create another EC2 instance to meet CPU demands. After 300 seconds, the script stops the high CPU usage and another CloudWatch alarm triggers below 205 CPU usage, triggering the ASG to scale-in EC2 instances.
