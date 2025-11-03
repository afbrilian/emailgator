terraform {
  required_version = ">= 1.0"

  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
  }

  # Optional: Configure remote state backend
  # Uncomment and configure when ready:
  # backend "s3" {
  #   bucket = "emailgator-terraform-state"
  #   key    = "terraform.tfstate"
  #   region = "us-east-1"
  # }
  #
  # Or use Terraform Cloud:
  # backend "remote" {
  #   organization = "your-org"
  #   workspaces {
  #     name = "emailgator-infra"
  #   }
  # }
}

provider "supabase" {
  access_token = var.supabase_api_key
}
