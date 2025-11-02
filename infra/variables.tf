variable "supabase_api_key" {
  description = "Supabase API key for authentication"
  type        = string
  sensitive   = true
}

variable "supabase_org_id" {
  description = "Supabase organization ID"
  type        = string
}

variable "project_name" {
  description = "Name of the Supabase project"
  type        = string
  default     = "emailgator"
}

variable "database_password" {
  description = "Password for the PostgreSQL database"
  type        = string
  sensitive   = true
  # Generate a secure password: openssl rand -base64 32
}

variable "region" {
  description = "AWS region for Supabase project"
  type        = string
  default     = "us-east-1"
}

variable "plan" {
  description = "Supabase plan (free, pro, team, enterprise)"
  type        = string
  default     = "free"
}
