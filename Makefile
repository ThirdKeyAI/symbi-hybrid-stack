.PHONY: init desktop-up desktop-down cloud-deploy cloud-teardown verify keygen logs help

SHELL := /bin/bash
ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## First-run setup: copy .env, generate keys, pull images, start stack
	@bash $(ROOT_DIR)/desktop/scripts/init.sh

desktop-up: ## Start desktop Docker Compose stack
	@echo "Starting desktop stack..."
	@if [ -f $(ROOT_DIR)/.env ]; then set -a && source $(ROOT_DIR)/.env && set +a; fi && \
		docker compose -f $(ROOT_DIR)/desktop/docker-compose.yml up -d
	@echo "Waiting for services to be healthy..."
	@bash $(ROOT_DIR)/desktop/scripts/healthcheck.sh
	@echo "Desktop stack is running."

desktop-down: ## Stop desktop stack gracefully
	@bash $(ROOT_DIR)/desktop/scripts/stop.sh

cloud-deploy: ## Deploy cloud standby via Terraform
	@bash $(ROOT_DIR)/cloud/scripts/deploy.sh

cloud-teardown: ## Destroy cloud resources
	@bash $(ROOT_DIR)/cloud/scripts/teardown.sh

verify: ## Run health checks and security validation
	@echo "=== Health Check ==="
	@bash $(ROOT_DIR)/desktop/scripts/healthcheck.sh
	@echo ""
	@echo "=== Security Verification ==="
	@bash $(ROOT_DIR)/security/verify-deployment.sh

keygen: ## Generate/rotate AgentPin identity keys
	@bash $(ROOT_DIR)/shared/identity/keygen.sh

logs: ## Tail logs from all services
	@docker compose -f $(ROOT_DIR)/desktop/docker-compose.yml logs -f --tail=100
