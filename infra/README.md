# Terraform Infrastructure for EmailGator

This directory contains Terraform configuration for provisioning the Supabase PostgreSQL database used by EmailGator.

## Prerequisites

1. **Terraform** installed (version >= 1.0)
   - Install from [terraform.io](https://www.terraform.io/downloads)

2. **Supabase Account**
   - Sign up at [supabase.com](https://supabase.com)
   - Create an organization if you haven't already

3. **Supabase API Key**
   - Go to your Supabase dashboard
   - Navigate to Account Settings > Access Tokens
   - Generate a new access token with appropriate permissions

4. **Organization ID**
   - Found in your Supabase dashboard URL or organization settings

## Setup

### 1. Configure Variables

Create a `terraform.tfvars` file in this directory:

```hcl
supabase_api_key = "your-supabase-api-key"
supabase_org_id  = "your-organization-id"
project_name     = "emailgator"
database_password = "generate-a-secure-password-here"
region           = "us-east-1"
plan             = "free"
```

**Important**: Never commit `terraform.tfvars` to version control. It contains sensitive information.

Generate a secure database password:
```bash
openssl rand -base64 32
```

### 2. Initialize Terraform

```bash
cd infra
terraform init
```

This will download the required providers.

### 3. Review the Plan

```bash
terraform plan
```

This will show you what resources will be created without making any changes.

### 4. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm the creation of resources.

### 5. Get the Database URL

After applying, retrieve the database connection string:

```bash
terraform output -raw database_url
```

This will output the `DATABASE_URL` that you need to set as a secret in Fly.io.

## Outputs

After `terraform apply`, you can get the following outputs:

- `database_url` - Connection string with connection pooling (recommended)
- `database_url_direct` - Direct connection string (for migrations)
- `project_id` - Supabase project ID
- `database_host` - Database hostname
- `database_port_pooled` - Port for pooled connections (6543)
- `database_port_direct` - Port for direct connections (5432)

### View all outputs:

```bash
terraform output
```

### Get specific output:

```bash
terraform output database_url
terraform output project_id
```

## Setting Up Fly.io Secrets

After provisioning the database, set the DATABASE_URL in Fly.io:

```bash
cd ../apps/api
fly secrets set DATABASE_URL="$(cd ../../infra && terraform output -raw database_url)"
```

Or manually:

```bash
fly secrets set DATABASE_URL="postgresql://postgres.xxx:password@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true"
```

## Destroying Resources

To tear down the infrastructure:

```bash
terraform destroy
```

**Warning**: This will delete the Supabase project and all data. Make sure you have backups if needed.

## Remote State (Optional)

For team collaboration, consider using remote state:

1. **Terraform Cloud** (recommended for teams):
   - Sign up at [app.terraform.io](https://app.terraform.io)
   - Create a workspace
   - Update `main.tf` backend configuration

2. **AWS S3** (for AWS users):
   - Create an S3 bucket for state
   - Update `main.tf` backend configuration
   - Enable versioning on the bucket

## Troubleshooting

### Provider Issues

If you encounter provider authentication issues:

1. Verify your API key is correct
2. Check that your API key has the necessary permissions
3. Ensure your organization ID is correct

### Resource Creation Errors

- Verify your Supabase account has available resources
- Check that the project name is unique
- Ensure the region is available for your plan

### Database Connection Issues

- Verify the DATABASE_URL format matches your Ecto configuration
- Check firewall/network settings if connections fail
- Use direct connection URL for migrations if pooled connection fails

## Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Terraform Supabase Provider](https://registry.terraform.io/providers/supabase/supabase/latest/docs)
- [Fly.io Secrets Documentation](https://fly.io/docs/reference/secrets/)
