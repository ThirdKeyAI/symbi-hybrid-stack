# symbi-hybrid-stack — Google Cloud infrastructure

# Artifact Registry for container images
resource "google_artifact_registry_repository" "symbi" {
  location      = var.region
  repository_id = var.artifact_registry_repo
  format        = "DOCKER"
  description   = "Symbi hybrid stack container images"
}

# GCS bucket for state replication (Litestream)
resource "google_storage_bucket" "state" {
  name          = var.gcs_state_bucket
  location      = var.region
  force_destroy = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
}

# Secret Manager — auth token
resource "google_secret_manager_secret" "auth_token" {
  secret_id = "symbi-auth-token"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "auth_token" {
  secret      = google_secret_manager_secret.auth_token.id
  secret_data = var.auth_token
}

# Secret Manager — LLM API key
resource "google_secret_manager_secret" "llm_api_key" {
  secret_id = "openrouter-api-key"

  replication {
    auto {}
  }
}

# Service accounts
resource "google_service_account" "coordinator" {
  account_id   = "symbi-coordinator"
  display_name = "Symbi Coordinator"
  description  = "Service account for the Symbi coordinator Cloud Run service"
}

resource "google_service_account" "worker" {
  account_id   = "symbi-worker"
  display_name = "Symbi Worker"
  description  = "Service account for Symbi worker Cloud Run services"
}

# IAM — coordinator can read secrets
resource "google_secret_manager_secret_iam_member" "coordinator_auth_token" {
  secret_id = google_secret_manager_secret.auth_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.coordinator.email}"
}

resource "google_secret_manager_secret_iam_member" "coordinator_llm_key" {
  secret_id = google_secret_manager_secret.llm_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.coordinator.email}"
}

# IAM — worker can read secrets
resource "google_secret_manager_secret_iam_member" "worker_auth_token" {
  secret_id = google_secret_manager_secret.auth_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_secret_manager_secret_iam_member" "worker_llm_key" {
  secret_id = google_secret_manager_secret.llm_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.worker.email}"
}

# IAM — coordinator can read/write GCS state bucket
resource "google_storage_bucket_iam_member" "coordinator_state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.coordinator.email}"
}

# Cloud Run — coordinator-standby
resource "google_cloud_run_v2_service" "coordinator" {
  name     = "coordinator-standby"
  location = var.region

  template {
    service_account = google_service_account.coordinator.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}/coordinator-standby:latest"

      ports {
        container_port = 8081
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = false
      }

      env {
        name = "SYMBI_AUTH_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.auth_token.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "OPENROUTER_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.llm_api_key.secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/webhook"
          port = 8081
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 10
      }

      liveness_probe {
        http_get {
          path = "/webhook"
          port = 8081
        }
        period_seconds    = 30
        failure_threshold = 3
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.symbi,
    google_secret_manager_secret_version.auth_token,
  ]
}

# Cloud Run — worker-agent
resource "google_cloud_run_v2_service" "worker" {
  name     = "worker-agent"
  location = var.region

  template {
    service_account = google_service_account.worker.email

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    max_instance_request_concurrency = 1
    timeout                          = "900s"

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}/worker-agent:latest"

      ports {
        container_port = 8081
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = false
      }

      env {
        name = "SYMBI_AUTH_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.auth_token.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "OPENROUTER_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.llm_api_key.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.symbi,
    google_secret_manager_secret_version.auth_token,
  ]
}
