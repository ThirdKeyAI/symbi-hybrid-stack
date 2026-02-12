#!/usr/bin/env bash
# teardown.sh — Destroy cloud resources
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# --- Load environment ---
if [ -f "$PROJECT_DIR/cloud/.env" ]; then
    set -a
    source "$PROJECT_DIR/cloud/.env"
    set +a
fi

GCP_PROJECT="${GCP_PROJECT_ID:-}"
GCP_REGION="${GCP_REGION:-us-central1}"
BUCKET="${GCS_STATE_BUCKET:-}"
REPO="${ARTIFACT_REGISTRY_REPO:-symbi}"

echo "=== Cloud Teardown ==="
echo ""
echo "This will destroy all cloud resources:"
echo "  - Cloud Run services (coordinator-standby, worker-agent)"
echo "  - Artifact Registry repository"
echo "  - Secret Manager secrets"
echo "  - GCS state bucket"
echo "  - IAM bindings"
echo ""

read -rp "Are you sure? Type 'yes' to confirm: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""

if command -v terraform &>/dev/null && [ -d "$PROJECT_DIR/cloud/terraform/.terraform" ]; then
    echo "Destroying with Terraform..."

    terraform -chdir="$PROJECT_DIR/cloud/terraform" destroy \
        -var="project_id=${GCP_PROJECT}" \
        -var="region=${GCP_REGION}" \
        -var="gcs_state_bucket=${BUCKET}" \
        -var="artifact_registry_repo=${REPO}" \
        -var="auth_token=placeholder"
else
    echo "Using gcloud to delete services..."

    gcloud run services delete coordinator-standby \
        --region "$GCP_REGION" --quiet 2>/dev/null || \
        echo "  coordinator-standby not found, skipping."

    gcloud run services delete worker-agent \
        --region "$GCP_REGION" --quiet 2>/dev/null || \
        echo "  worker-agent not found, skipping."

    echo ""
    echo "Note: GCS bucket, Artifact Registry, and Secret Manager resources"
    echo "were not deleted (manual cleanup needed without Terraform)."
fi

echo ""
echo "Cloud teardown complete."
