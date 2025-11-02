resource "supabase_project" "emailgator" {
  organization_id = var.supabase_org_id
  name            = var.project_name
  region          = var.region
  plan            = var.plan
  database_password = var.database_password
}

# Connection pooling configuration is handled automatically by Supabase
# For direct database connections, use the connection string from outputs
# For connection pooling, Supabase provides a separate pooler URL
