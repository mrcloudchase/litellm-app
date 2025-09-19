# Use specific version instead of latest for reproducibility
FROM ghcr.io/berriai/litellm:main-stable

# Set secure working directory
WORKDIR /app

# Copy files with secure permissions (LiteLLM base image uses root, we'll use nobody)
COPY --chown=nobody:nogroup litellm-config.yaml /app/litellm-config.yaml
COPY --chown=nobody:nogroup pii_regex_detection.py /app/pii_regex_detection.py
COPY --chown=nobody:nogroup pii_regex_precall.py /app/pii_regex_precall.py
COPY --chown=nobody:nogroup pii_regex_postcall.py /app/pii_regex_postcall.py

# Set secure file permissions
RUN chmod 644 /app/*.py /app/*.yaml

# Set production environment
ENV LITELLM_MODE=PRODUCTION

# Create cache directory with proper permissions for nobody user
RUN mkdir -p /.cache && chmod 777 /.cache

# Switch to non-root user (nobody exists in most base images)
USER nobody

# Use non-privileged port (already 4000)
EXPOSE 4000

# Use exec form for better signal handling
CMD ["--port", "4000", "--config", "/app/litellm-config.yaml"]

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1
