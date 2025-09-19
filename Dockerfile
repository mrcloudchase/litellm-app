# Use specific version instead of latest for reproducibility
FROM ghcr.io/berriai/litellm:main-stable

# Set secure working directory
WORKDIR /app

# Install Microsoft Presidio analyzer for comprehensive PII detection
RUN pip install --no-cache-dir --quiet presidio-analyzer

# Copy files
COPY litellm-config.yaml /app/litellm-config.yaml
COPY pii_regex_detection.py /app/pii_regex_detection.py
COPY pii_regex_precall.py /app/pii_regex_precall.py
COPY pii_regex_postcall.py /app/pii_regex_postcall.py
COPY pii_presidio_detection.py /app/pii_presidio_detection.py
COPY pii_presidio_precall.py /app/pii_presidio_precall.py
COPY pii_presidio_postcall.py /app/pii_presidio_postcall.py

# Set secure file permissions
RUN chmod 644 /app/*.py /app/*.yaml

# Create cache directory with proper permissions
RUN mkdir -p /.cache && chmod 777 /.cache
RUN mkdir -p /.npm && chmod 777 /.npm

# Use port 4000
EXPOSE 4000

# Use exec form for better signal handling
CMD ["--port", "4000", "--config", "/app/litellm-config.yaml"]

# Add health check - 401 response means service is healthy and just needs authentication
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/health | grep -E "^(200|401)$" > /dev/null || exit 1
