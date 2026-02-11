output "coordinator_url" {
  description = "Cloud Run URL for the coordinator-standby service"
  value       = google_cloud_run_v2_service.coordinator.uri
}

output "worker_url" {
  description = "Cloud Run URL for the worker-agent service"
  value       = google_cloud_run_v2_service.worker.uri
}

output "gcs_state_bucket" {
  description = "GCS bucket for state replication"
  value       = google_storage_bucket.state.name
}

output "artifact_registry" {
  description = "Artifact Registry path for container images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.symbi.repository_id}"
}
