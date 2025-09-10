# vpc-endpoints-demo 
In this project, I will demonstrate how to access S3 bucket using VPC endpoint. I'm doing this project to learn how to securely access the bucket via VPC endpoints instead of direct public internet through internet gateway.

# Tech-Stack used 

- Terraform
- AWS VPC, EC2 instance and S3 bucket
- IntelliJ IDE

# Architecture

![Alt text](https://github.com/diptishegar/vpc-endpoints-demo/blob/main/architecture-today.png)

# S3 VPC Endpoint Demo Steps

## Prerequisites
- AWS CLI configured with credentials
- Terraform installed
- Your existing key pair name in AWS

## Step 1: Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Deploy all resources
terraform apply -auto-approve
```

## Step 2: Upload Test File to S3
```bash
# Create a test file
echo "Hello from VPC Endpoint!" > test-file.txt

# Upload to your S3 bucket (get bucket name from terraform output)
aws s3 cp test-file.txt s3://YOUR-BUCKET-NAME/
```

## Step 3: Connect to EC2 Instance
```bash
# SSH into the EC2 instance (use the command from terraform output)
ssh -i /path/to/your-key.pem ec2-user@YOUR-EC2-PUBLIC-IP
```

## Step 4: Test S3 Access via VPC Endpoint
```bash
# Inside the EC2 instance, install AWS CLI
sudo yum update -y
sudo yum install -y aws-cli

# Configure AWS CLI (use IAM role or provide credentials)
aws configure

# Test S3 access - this will go through VPC endpoint
aws s3 ls s3://YOUR-BUCKET-NAME/
aws s3 cp s3://YOUR-BUCKET-NAME/test-file.txt ./downloaded-file.txt
cat downloaded-file.txt
```

## Step 5: Verify VPC Endpoint Usage
```bash
# Check route table to see S3 endpoint routes
aws ec2 describe-route-tables --route-table-ids YOUR-ROUTE-TABLE-ID

# Test connectivity to S3 endpoint
nslookup s3.amazonaws.com
# Should resolve to VPC endpoint IP, not public S3 IP
```

## Step 6: Demonstrate Cost Savings
```bash
# Show that traffic goes through VPC endpoint (no internet gateway charges)
# Check VPC Flow Logs or CloudTrail for S3 API calls via endpoint

# Compare: Disable VPC endpoint temporarily and test again
# (Traffic would then go via Internet Gateway - incurring charges)
```

## Step 7: Clean Up Resources
```bash
# Remove test file from S3
aws s3 rm s3://YOUR-BUCKET-NAME/test-file.txt

# Destroy all Terraform resources
terraform destroy -auto-approve
```

## Expected Results
- ✅ S3 bucket accessible from EC2 via VPC endpoint
- ✅ No internet gateway charges for S3 traffic
- ✅ Improved security (traffic stays within AWS network)
- ✅ Faster access to S3 (direct AWS backbone connection)

## Key Verification Points
1. **Route Table**: Shows S3 service routes via VPC endpoint
2. **Network Traffic**: S3 requests don't go through Internet Gateway
3. **DNS Resolution**: S3 URLs resolve to VPC endpoint IPs
4. **Cost**: No data transfer charges for S3 access
