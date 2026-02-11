variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "us-central1"
}

variable "domain" {
  description = "Domain for AgentPin identity"
  type        = string
  default     = ""
}

variable "artifact_registry_repo" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "symbi"
}

variable "gcs_state_bucket" {
  description = "GCS bucket name for state replication"
  type        = string
}

variable "auth_token" {
  description = "Symbiont HTTP API auth token"
  type        = string
  sensitive   = true
}
