output "database_url" {
  description = "PostgreSQL connection string (DATABASE_URL format)"
  value       = "postgresql://postgres.${supabase_project.emailgator.id}:${var.database_password}@aws-0-${var.region}.pooler.supabase.com:6543/postgres?pgbouncer=true"
  sensitive   = true
}

output "database_url_direct" {
  description = "PostgreSQL direct connection string (without connection pooling)"
  value       = "postgresql://postgres.${supabase_project.emailgator.id}:${var.database_password}@aws-0-${var.region}.pooler.supabase.com:5432/postgres"
  sensitive   = true
}

output "project_id" {
  description = "Supabase project ID"
  value       = supabase_project.emailgator.id
}

output "project_ref" {
  description = "Supabase project reference"
  value       = supabase_project.emailgator.id
}

output "database_host" {
  description = "Database hostname"
  value       = "aws-0-${var.region}.pooler.supabase.com"
}

output "database_port_pooled" {
  description = "Database port for connection pooling"
  value       = 6543
}

output "database_port_direct" {
  description = "Database port for direct connections"
  value       = 5432
}

output "database_name" {
  description = "Database name"
  value       = "postgres"
}
