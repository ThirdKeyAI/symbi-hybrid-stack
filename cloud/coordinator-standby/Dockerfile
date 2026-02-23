FROM ghcr.io/thirdkeyai/symbi:latest

# Copy configuration and agent definitions
# Build context is repo root (docker build -f cloud/coordinator-standby/Dockerfile .)
COPY cloud/coordinator-standby/symbi.toml /var/lib/symbi/symbi.toml
COPY desktop/agents/ /etc/symbi/agents/
COPY desktop/policies/ /etc/symbi/policies/

# Cloud Run sets PORT; HOME must point to a writable dir (no /home/symbi in image)
ENV PORT=8081 HOME=/var/lib/symbi

# Shell form for $SYMBI_AUTH_TOKEN expansion; exec replaces sh so symbi is PID 1
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["exec /usr/local/bin/symbi up --port 8080 --http-port 8081 --http.token \"$SYMBI_AUTH_TOKEN\" --http.audit"]
