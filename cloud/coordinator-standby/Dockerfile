FROM ghcr.io/thirdkeyai/symbi:latest

# Copy configuration and agent definitions
# Build context is repo root (docker build -f cloud/coordinator-standby/Dockerfile .)
COPY cloud/coordinator-standby/symbi.toml /etc/symbi/symbi.toml
COPY desktop/agents/ /etc/symbi/agents/
COPY desktop/policies/ /etc/symbi/policies/

# Cloud Run sets PORT environment variable
ENV PORT=8081

ENTRYPOINT ["/usr/local/bin/symbi"]
CMD ["up", "--port", "8080", "--http-port", "8081", "--http.token", "env:SYMBI_AUTH_TOKEN", "--http.audit"]
