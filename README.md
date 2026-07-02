# shuli-infrastructure
Infrastructure as Code (IaC) for Shuli's project using Terraform, covering RDS, Elastic Beanstalk, and CI/CD pipelines.

# Shuli Project Infrastructure

This repository contains the Terraform configuration for the Shuli project's cloud infrastructure on AWS.

## Architecture
- **RDS:** PostgreSQL managed database.
- **Elastic Beanstalk:** Hosting the Backend & Frontend applications.
- **CI/CD:** Automated pipelines via AWS CodePipeline.

## Project Structure
- `modules/`: Reusable Terraform modules.
- `environments/`: Environment-specific configurations (Dev/Prod).

## Prerequisites
- Terraform installed
- AWS CLI configured with appropriate credentials
