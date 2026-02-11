FROM ghcr.io/thirdkeyai/symbi:latest

# Copy agent definitions and policies
COPY ../../desktop/agents/ /etc/symbi/agents/
COPY ../../desktop/policies/ /etc/symbi/policies/

# Workers process tasks from queue — no HTTP endpoint needed
# Cloud Run requires a port listener, so we keep the HTTP server
ENV PORT=8081

ENTRYPOINT ["/usr/local/bin/symbi"]
CMD ["up", "--port", "8080", "--http-port", "8081", "--http.token", "env:SYMBI_AUTH_TOKEN", "--http.audit"]
