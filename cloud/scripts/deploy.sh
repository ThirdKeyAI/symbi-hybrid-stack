#!/usr/bin/env bash
# deploy.sh — Deploy cloud standby services
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_DIR"

# --- Load environment ---
if [ -f cloud/.env ]; then
    set -a
    source cloud/.env
    set +a
fi

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

GCP_PROJECT="${GCP_PROJECT_ID:-}"
GCP_REGION="${GCP_REGION:-us-central1}"
BUCKET="${GCS_STATE_BUCKET:-}"
REPO="${ARTIFACT_REGISTRY_REPO:-symbi}"

# --- Validate prerequisites ---
echo "=== Cloud Deployment ==="
echo ""

MISSING=""
if [ -z "$GCP_PROJECT" ]; then MISSING="${MISSING}  - GCP_PROJECT_ID\n"; fi
if [ -z "$BUCKET" ]; then MISSING="${MISSING}  - GCS_STATE_BUCKET\n"; fi

if [ -n "$MISSING" ]; then
    echo "Error: Missing required environment variables:"
    echo -e "$MISSING"
    echo "Set these in cloud/.env"
    exit 1
fi

if ! command -v gcloud &>/dev/null; then
    echo "Error: gcloud CLI not found."
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# --- Authenticate ---
echo "Authenticating with GCP project: $GCP_PROJECT..."
gcloud config set project "$GCP_PROJECT" --quiet

# --- Build and push images ---
REGISTRY="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${REPO}"

echo ""
echo "Building coordinator-standby image..."
docker build \
    -t "${REGISTRY}/coordinator-standby:latest" \
    -f cloud/coordinator-standby/Dockerfile \
    .

echo ""
echo "Building worker-agent image..."
docker build \
    -t "${REGISTRY}/worker-agent:latest" \
    -f cloud/worker-agent/Dockerfile \
    .

echo ""
echo "Pushing images to Artifact Registry..."
docker push "${REGISTRY}/coordinator-standby:latest"
docker push "${REGISTRY}/worker-agent:latest"

# --- Deploy with Terraform ---
echo ""
if command -v terraform &>/dev/null; then
    echo "Deploying with Terraform..."
    cd cloud/terraform

    terraform init \
        -backend-config="bucket=${BUCKET}" \
        -backend-config="prefix=terraform/state"

    terraform apply \
        -var="project_id=${GCP_PROJECT}" \
        -var="region=${GCP_REGION}" \
        -var="gcs_state_bucket=${BUCKET}" \
        -var="artifact_registry_repo=${REPO}" \
        -var="auth_token=${SYMBI_AUTH_TOKEN:-}"

    echo ""
    echo "Terraform outputs:"
    terraform output
else
    echo "Terraform not found — falling back to gcloud..."

    # Deploy coordinator-standby
    gcloud run deploy coordinator-standby \
        --image "${REGISTRY}/coordinator-standby:latest" \
        --region "$GCP_REGION" \
        --platform managed \
        --no-allow-unauthenticated \
        --min-instances 0 \
        --max-instances 2 \
        --memory 512Mi \
        --cpu 1 \
        --quiet

    # Deploy worker-agent
    gcloud run deploy worker-agent \
        --image "${REGISTRY}/worker-agent:latest" \
        --region "$GCP_REGION" \
        --platform managed \
        --no-allow-unauthenticated \
        --min-instances 0 \
        --max-instances 10 \
        --memory 512Mi \
        --cpu 1 \
        --concurrency 1 \
        --timeout 900 \
        --quiet

    echo ""
    echo "Services deployed:"
    gcloud run services list --region "$GCP_REGION" --format="table(name,status.url)"
fi

echo ""
echo "Cloud deployment complete."
