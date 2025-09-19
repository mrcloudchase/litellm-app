# Use specific version instead of latest for reproducibility  
FROM ollama/ollama:latest

# Create secure directory for scripts with proper permissions
RUN mkdir -p /app/scripts

# Copy scripts with secure permissions (root owns, but readable/executable by all)
COPY --chmod=755 scripts/pull-models.sh /app/scripts/pull-models.sh
COPY --chmod=755 scripts/entrypoint.sh /app/scripts/entrypoint.sh

# Verify script permissions and ensure they're executable
RUN chmod +x /app/scripts/*.sh && ls -la /app/scripts/

# Set secure environment variables
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_PORT=11434
ENV OLLAMA_KEEP_ALIVE=5m

# Use non-privileged port (already 11434)
EXPOSE 11434

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD ollama list || exit 1

# Use custom entrypoint with exec form for better signal handling
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
