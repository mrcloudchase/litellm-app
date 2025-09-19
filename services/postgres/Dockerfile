# Use specific version for reproducibility and security
FROM postgres:16.6-alpine

# Install security updates and clean up
RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

# Copy initialization scripts with secure permissions
COPY --chown=postgres:postgres init/ /docker-entrypoint-initdb.d/

# Set secure permissions on init scripts
RUN chmod 755 /docker-entrypoint-initdb.d/ && \
    chmod 644 /docker-entrypoint-initdb.d/*.sql

# Remove default environment variables for security (use docker-compose env vars)
# ENV POSTGRES_DB=litellm_db
# ENV POSTGRES_USER=litellm  
# ENV POSTGRES_PASSWORD=litellm_secure_password

# Configure PostgreSQL for security
RUN echo "# Security configurations" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "log_connections = on" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "log_disconnections = on" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "log_statement = 'mod'" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "shared_preload_libraries = 'pg_stat_statements'" >> /usr/local/share/postgresql/postgresql.conf.sample

# Use non-privileged port (already 5432 is standard)
EXPOSE 5432

# Add health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=5 \
    CMD pg_isready -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres} || exit 1

# Use default PostgreSQL entrypoint (already runs as postgres user)
CMD ["postgres"]
