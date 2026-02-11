terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }

  backend "gcs" {
    # Configure via: terraform init -backend-config="bucket=YOUR_BUCKET" -backend-config="prefix=terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
