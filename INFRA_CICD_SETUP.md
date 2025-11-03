# Infrastructure CI/CD Setup Guide

Complete step-by-step guide for setting up Terraform infrastructure deployment via GitHub Actions.

## Overview

This guide will help you configure automated infrastructure provisioning using Terraform and GitHub Actions. The infrastructure workflow will:

- Automatically plan changes on pull requests
- Apply changes when merging to `main`
- Allow manual workflow triggers for plan/apply/destroy
- Provision Supabase PostgreSQL database automatically

## Prerequisites

Before starting, ensure you have:

1. ✅ A GitHub repository with the EmailGator codebase
2. ✅ A Supabase account ([sign up here](https://supabase.com))
3. ✅ Access to GitHub repository settings

## Step-by-Step Configuration

### Step 1: Get Your Supabase Credentials

You need two pieces of information from Supabase:

#### 1.1 Get Supabase API Key

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Click your profile icon (top right)
3. Click **Account Settings**
4. Navigate to **Access Tokens** section
5. Click **Generate new token**
6. Give it a name (e.g., "GitHub Actions Terraform")
7. Copy the token - you'll need this for GitHub Secrets

#### 1.2 Get Organization ID

1. Stay in the [Supabase Dashboard](https://supabase.com/dashboard)
2. Look at the URL - it should be: `https://supabase.com/dashboard/organizations/[ORG_ID]/projects`
3. The `[ORG_ID]` part is your organization ID
4. Or go to **Settings** → **General** → your organization section
5. Copy the organization ID

### Step 2: Generate a Secure Database Password

Generate a secure password for your database:

```bash
openssl rand -base64 32
```

Copy this password - you'll need it for GitHub Secrets.

**Important**: Save this password securely. You won't be able to retrieve it later!

### Step 3: Configure GitHub Secrets

Now we'll add the required secrets to GitHub:

1. Go to your GitHub repository
2. Click **Settings** (top navigation)
3. Click **Secrets and variables** → **Actions**
4. Click **New repository secret**

Add each secret below:

#### Required Secrets

| Secret Name | Value | Where to Get |
|------------|-------|--------------|
| `SUPABASE_API_KEY` | Your Supabase API token | Step 1.1 above |
| `SUPABASE_ORG_ID` | Your organization ID | Step 1.2 above |
| `DATABASE_PASSWORD` | Generated secure password | Step 2 above |

#### Optional Secrets (with defaults)

| Secret Name | Default Value | When to Override |
|------------|---------------|------------------|
| `TERRAFORM_PROJECT_NAME` | `emailgator` | If you want a different project name |
| `TERRAFORM_REGION` | `us-east-1` | If you want a different AWS region |
| `TERRAFORM_PLAN` | `free` | If you want a different Supabase plan |

**To add secrets:**
1. For each secret, click **New repository secret**
2. Enter the **Name** (exactly as shown in the table)
3. Enter the **Secret** value
4. Click **Add secret**

**Important**: Secret names are **case-sensitive**. Match them exactly!

### Step 4: Verify Terraform Configuration

Let's verify your Terraform setup is correct:

1. **Check terraform.tfvars is ignored:**

   Your `.gitignore` should already have `infra/terraform.tfvars`. Verify:

   ```bash
   git status --short infra/terraform.tfvars
   ```

   Should return nothing (no output).

2. **Verify Terraform files exist:**

   ```bash
   ls -la infra/*.tf
   ```

   Should show: `database.tf`, `main.tf`, `outputs.tf`, `variables.tf`

### Step 5: Test the Infrastructure Workflow

Now let's test if everything works!

#### 5.1 Create a Test Pull Request

1. Create a new branch:
   ```bash
   git checkout -b test/infra-setup
   ```

2. Make a small change to trigger the workflow:
   ```bash
   # Add a comment to database.tf
   echo "# Test comment" >> infra/database.tf
   ```

3. Commit and push:
   ```bash
   git add infra/database.tf
   git commit -m "test: Infrastructure CI/CD setup"
   git push origin test/infra-setup
   ```

4. Create a Pull Request on GitHub

#### 5.2 Check the Workflow Run

1. Go to your repository on GitHub
2. Click **Actions** tab
3. Find the **Infrastructure CI/CD** workflow
4. Click on it to see details
5. The workflow should run `terraform plan`

**What to expect:**
- ✅ Green checkmark = Terraform plan succeeded
- ❌ Red X = Check the logs for errors

**Common issues:**
- Missing secrets → Add missing GitHub Secrets
- Invalid credentials → Verify Supabase API key and org ID
- Workflow not triggered → Ensure the branch name and file paths match

#### 5.3 Merge the Pull Request

Once the plan looks good:

1. Merge the pull request to `main`
2. Go to **Actions** tab
3. Watch the workflow run again
4. This time it will run `terraform apply`

**First apply will:**
- Create a new Supabase project
- Provision PostgreSQL database
- Output database connection string

**Note**: First deployment may take 5-10 minutes as Supabase provisions resources.

### Step 6: Configure Fly.io Secrets

After Terraform successfully applies, you need to get the database URL and set it in Fly.io:

#### 6.1 Get Database URL from Terraform Output

Run this locally (if you have Terraform installed):

```bash
cd infra
terraform output -raw database_url
```

Or check the GitHub Actions logs for the output.

#### 6.2 Set Fly.io Secret

```bash
cd apps/api
fly secrets set DATABASE_URL="<paste-database-url-here>" --app emailgator-api
```

### Step 7: Configure Database with Fly.io Secrets (Automated)

Alternatively, you can automate this by adding a job to the workflow that sets the Fly.io secret automatically. However, this requires:

1. `FLY_API_TOKEN` GitHub secret (already needed for API/Sidecar deployments)
2. Modified workflow to call Fly.io CLI

See **Advanced Configuration** section below for this option.

## How It Works

### Workflow Triggers

The infrastructure workflow runs in these scenarios:

| Trigger | Action | When |
|---------|--------|------|
| Pull Request | `terraform plan` | Automatic - shows what will change |
| Push to `main` | `terraform apply` | Automatic - applies changes |
| Manual trigger | Choose action | On-demand via GitHub UI |

### Manual Workflow Trigger

You can manually trigger the workflow:

1. Go to **Actions** → **Infrastructure CI/CD**
2. Click **Run workflow**
3. Choose action: `plan`, `apply`, or `destroy`
4. Click **Run workflow**

**Warning**: `destroy` action requires environment protection rules and approval!

### Terraform State Management

By default, Terraform state is stored locally in GitHub Actions. For production use, consider:

- **Terraform Cloud** (recommended): Free for small teams
- **AWS S3**: If you're using AWS
- **Azure Blob Storage**: If you're using Azure

See `infra/README.md` for configuration details.

## Advanced Configuration

### Option 1: Auto-configure Fly.io Secrets

Add this job to `.github/workflows/infra.yml` after the `terraform-apply` job:

```yaml
setup-fly-secrets:
  runs-on: ubuntu-latest
  needs: terraform-apply
  if: needs.terraform-apply.result == 'success'

  steps:
    - uses: actions/checkout@v4

    - name: Setup Fly.io
      uses: superfly/flyctl-actions/setup-flyctl@master

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3

    - name: Get Database URL
      id: outputs
      run: |
        cd infra
        terraform init
        DATABASE_URL=$(terraform output -raw database_url)
        echo "DATABASE_URL=$DATABASE_URL" >> $GITHUB_ENV
      env:
        TF_VAR_supabase_api_key: ${{ secrets.SUPABASE_API_KEY }}
        TF_VAR_supabase_org_id: ${{ secrets.SUPABASE_ORG_ID }}
        TF_VAR_project_name: ${{ secrets.TERRAFORM_PROJECT_NAME || 'emailgator' }}
        TF_VAR_database_password: ${{ secrets.DATABASE_PASSWORD }}
        TF_VAR_region: ${{ secrets.TERRAFORM_REGION || 'us-east-1' }}
        TF_VAR_plan: ${{ secrets.TERRAFORM_PLAN || 'free' }}

    - name: Update Fly.io Secrets
      env:
        FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
      run: |
        flyctl secrets set DATABASE_URL="$DATABASE_URL" --app emailgator-api
```

### Option 2: Remote State Backend

Configure remote state to share Terraform state across workflows:

1. **Terraform Cloud**:
   - Sign up at [app.terraform.io](https://app.terraform.io)
   - Create a workspace
   - Add `TERRAFORM_CLOUD_TOKEN` to GitHub Secrets
   - Update `infra/main.tf` backend configuration

2. **AWS S3**:
   - Create S3 bucket
   - Enable versioning
   - Create DynamoDB table for state locking
   - Update `infra/main.tf` backend configuration

See `infra/README.md` for more details.

### Option 3: Custom Environment Protection

Add approval gates for destructive operations:

1. Go to repository **Settings** → **Environments**
2. Create environment: `production`
3. Enable **Required reviewers**
4. The `destroy` job in the workflow uses this environment

## Troubleshooting

### Issue: Workflow fails with "authentication error"

**Solution**: Check that `SUPABASE_API_KEY` and `SUPABASE_ORG_ID` are correct.

```bash
# Verify your org ID is correct
# Check URL: https://supabase.com/dashboard/organizations/[ORG_ID]/projects
```

### Issue: Workflow fails with "resource already exists"

**Solution**: Supabase project name already taken. Either:
- Delete the existing project from Supabase dashboard
- Change `TERRAFORM_PROJECT_NAME` secret to a unique name

### Issue: Can't get database URL after apply

**Solution**: Terraform outputs are masked for security. Either:
- Run `terraform output` locally if you have Terraform installed
- Check the workflow logs for the output (it's shown in notices)
- Enable the "Auto-configure Fly.io Secrets" option above

### Issue: Database connection fails

**Solution**: Verify:
1. Database is fully provisioned (may take 5-10 minutes)
2. Database URL is correct
3. Fly.io can reach Supabase (network/firewall issues)

### Issue: Workflow not triggering

**Solution**: Check:
1. Branch is `main` or `master`
2. Files changed are in `infra/` directory
3. Workflow file exists at `.github/workflows/infra.yml`
4. No syntax errors in workflow file

## Testing Your Setup

After configuration, test the complete flow:

1. **Make a test change** to `infra/database.tf`
2. **Create a PR** → Should trigger `terraform plan`
3. **Review the plan** → Ensure changes are expected
4. **Merge to main** → Should trigger `terraform apply`
5. **Check Supabase** → Verify project was created
6. **Check Fly.io** → Verify DATABASE_URL secret is set
7. **Deploy backend** → Should connect to database successfully

## Next Steps

After infrastructure is set up:

1. ✅ Complete [DEPLOYMENT.md](./DEPLOYMENT.md) Phase 2: Configure Secrets
2. ✅ Deploy backend API ([DEPLOYMENT.md](./DEPLOYMENT.md) Phase 3.1) **FIRST** - Frontend needs API for GraphQL codegen
3. ✅ Deploy frontend (automatic via GitHub Actions) - After API is live
4. ✅ Verify deployment (DEPLOYMENT.md Phase 4)

**Important**: Deploy backend API before frontend. The frontend runs GraphQL codegen during build, which requires the API to be accessible. If the API isn't deployed yet, the frontend will use existing generated types from the repository.

## Security Best Practices

1. ✅ Never commit `terraform.tfvars` to version control
2. ✅ Rotate `DATABASE_PASSWORD` periodically
3. ✅ Use environment protection for destructive operations
4. ✅ Monitor Supabase usage and costs
5. ✅ Enable Terraform Cloud remote state for teams
6. ✅ Review all Terraform plans before applying

## Additional Resources

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Full deployment guide
- [infra/README.md](./infra/README.md) - Terraform documentation
- [Supabase Documentation](https://supabase.com/docs)
- [Terraform Documentation](https://www.terraform.io/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## Support

If you encounter issues:

1. Check the GitHub Actions logs for error messages
2. Review this guide's troubleshooting section
3. Check Supabase dashboard for project status
4. Verify all secrets are set correctly
5. Open an issue in the repository

## Checklist

Use this checklist to ensure everything is configured:

- [ ] Supabase account created
- [ ] Supabase API key generated
- [ ] Organization ID obtained
- [ ] Database password generated
- [ ] GitHub Secrets configured
- [ ] `.gitignore` includes `infra/terraform.tfvars`
- [ ] Test PR created and plan succeeds
- [ ] Merged to main and apply succeeds
- [ ] Database provisioned in Supabase
- [ ] Fly.io secrets configured
- [ ] Backend deployment connects to database
- [ ] Health checks pass

---

**Ready to deploy?** Continue with [DEPLOYMENT.md](./DEPLOYMENT.md) for application deployment!

