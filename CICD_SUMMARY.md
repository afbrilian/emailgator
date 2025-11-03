# EmailGator CI/CD Summary

Quick reference for all CI/CD workflows and their triggers.

## Workflows Overview

EmailGator uses GitHub Actions for automated deployment across all components:

| Workflow | Path | Triggers | Actions |
|----------|------|----------|---------|
| **Infrastructure** | `.github/workflows/infra.yml` | Push/PR to `infra/**`, Manual | Terraform plan/apply/destroy |
| **API** | `.github/workflows/api.yml` | Push/PR to `apps/api/**` | Test, build, deploy backend |
| **Sidecar** | `.github/workflows/sidecar.yml` | Push/PR to `sidecar/**` | Test, verify, deploy sidecar |
| **Web** | `.github/workflows/web.yml` | Push/PR to `apps/web/**` | Test, build, deploy frontend |

## Quick Setup Guide

### 1. Infrastructure CI/CD
👉 **See [INFRA_CICD_SETUP.md](./INFRA_CICD_SETUP.md) for complete instructions**

**Required GitHub Secrets:**
- `SUPABASE_API_KEY`
- `SUPABASE_ORG_ID`
- `DATABASE_PASSWORD`

**What it does:**
- Plans changes on pull requests
- Applies on merge to `main`
- Provisions Supabase database automatically

### 2. Application CI/CD
👉 **See [DEPLOYMENT.md](./DEPLOYMENT.md) for complete instructions**

**Required GitHub Secrets:**
- `FLY_API_TOKEN` - For API and Sidecar deployments
- `VERCEL_TOKEN` - For frontend deployments
- `VERCEL_ORG_ID` - Vercel organization
- `VERCEL_PROJECT_ID` - Vercel project
- `NEXT_PUBLIC_API_URL` - API URL for GraphQL codegen

**What they do:**
- Run tests automatically
- Build and deploy on merge to `main`
- Run health checks after deployment

## Deployment Order

Follow this order for initial deployment:

1. **Infrastructure** → Provision database
2. **Configure Fly.io secrets** → Database URL, API secrets
3. **Deploy API** → Backend service
4. **Deploy Sidecar** → Background processing
5. **Deploy Web** → Frontend (optional, can deploy anytime)

## Workflow Triggers

### Automatic Triggers

- **Push to `main/master`**: Deploys to production
- **Pull Request**: Runs tests and plans

### Manual Triggers

All workflows support manual triggers via GitHub UI:
1. Go to **Actions** → Select workflow
2. Click **Run workflow**
3. Choose branch and options

## Environment Protection

The infrastructure `destroy` job requires explicit approval:
1. Go to **Settings** → **Environments**
2. Create `production` environment
3. Enable **Required reviewers**

## Monitoring

Check deployment status:
- GitHub → **Actions** tab
- Fly.io → App logs and metrics
- Vercel → Deployment dashboard
- Supabase → Database logs

## Rollback

Each platform supports rollback:

| Platform | Rollback Command |
|----------|------------------|
| **Fly.io** | `fly releases rollback <version>` |
| **Vercel** | Dashboard → Deployments → Promote previous |
| **Infrastructure** | Manual or workflow_dispatch → destroy + re-apply |

## Support

- Infrastructure: [INFRA_CICD_SETUP.md](./INFRA_CICD_SETUP.md)
- Full deployment: [DEPLOYMENT.md](./DEPLOYMENT.md)
- Terraform: [infra/README.md](./infra/README.md)

## Checklist

Use this to ensure everything is configured:

- [ ] All GitHub Secrets configured
- [ ] Infrastructure provisioned (or manual setup complete)
- [ ] Fly.io apps created (emailgator-api, emailgator-sidecar)
- [ ] Vercel project configured
- [ ] All workflows passing tests
- [ ] Successful production deployments
- [ ] Health checks passing

---

**Next Steps:**
1. If using CI/CD for infrastructure: Start with [INFRA_CICD_SETUP.md](./INFRA_CICD_SETUP.md)
2. For manual infrastructure: Follow [infra/README.md](./infra/README.md)
3. Then proceed with [DEPLOYMENT.md](./DEPLOYMENT.md) for application deployment

