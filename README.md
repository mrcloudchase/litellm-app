# LiteLLM App - Container Image Builder

A production-ready LiteLLM deployment with custom regex-based PII detection guardrails, designed for **container image building** and **automated ECR publishing**.

## 🎯 Repository Purpose

This repository builds and publishes security-hardened container images to AWS ECR for use in infrastructure deployments.

- **Container Image Building**: Multi-platform Docker builds (amd64/arm64)
- **ECR Publishing**: Automated CI/CD pipeline via GitHub Actions
- **Security Hardened**: Enterprise-grade container security best practices
- **Infrastructure Ready**: Images designed for deployment in AWS infrastructure

## 🏗️ Architecture

```
LiteLLM App Stack:
└── LiteLLM Proxy (Port 4000)     # Main service with embedded regex-based PII guardrails
```

## 📦 Published Container Images

This repository automatically builds and publishes this image to ECR:

| Service | ECR Repository | Description |
|---------|---------------|-------------|
| **LiteLLM** | `chasedecr.dkr.ecr.us-east-1.amazonaws.com/litellm-guardrails` | LiteLLM proxy with custom regex-based PII detection guardrails |

## 🚀 CI/CD Pipeline

### Automated Builds
- **Trigger**: Push to `main` branch
- **Platforms**: linux/amd64, linux/arm64
- **Tags**: `latest` and `{commit-sha}`
- **Caching**: GitHub Actions cache for faster builds
- **Security**: Non-root execution, minimal base images

### Required GitHub Secrets
```
AWS_ACCESS_KEY_ID     # AWS access key with ECR push permissions
AWS_SECRET_ACCESS_KEY # Corresponding AWS secret access key
```

## 🔧 Local Development

### Quick Start
```bash
# Clone repository
git clone https://github.com/mrcloudchase/litellm-app.git
cd litellm-app

# Start local development stack
docker compose up -d

# Test the deployment
curl http://localhost:4000/health
```

### Available Services
- **LiteLLM API**: http://localhost:4000

## 🛡️ Security Features

All published images include enterprise security hardening:

- ✅ **Non-root execution** where applicable
- ✅ **Minimal base images** (Alpine Linux for PostgreSQL)
- ✅ **Secure file permissions** (644 for configs, 755 for scripts)
- ✅ **Health checks** built into all images
- ✅ **Security logging** enabled
- ✅ **Multi-platform builds** (amd64/arm64)

## 🔍 PII Detection Capabilities

### Custom Regex Guardrails
- **Email addresses**: `user@domain.com`, `user+tag@domain.org`
- **Social Security Numbers**: `123-45-6789`, `123 45 6789`, `123456789`
- **Phone numbers**: `(555) 123-4567`, `555-123-4567`, `+1 555 123 4567`
- **Credit card numbers**: Visa, MasterCard, Amex, Discover formats
- **Pre-call and post-call detection**: Blocks PII in both user input and model responses
- **Fast pattern-based detection**: Low latency regex-based matching

## 🏷️ Image Usage

### In Docker Compose
```yaml
version: '3.8'
services:
  litellm:
    image: chasedecr.dkr.ecr.us-east-1.amazonaws.com/litellm-guardrails:latest
    ports:
      - "4000:4000"
    environment:
      - LITELLM_MASTER_KEY=your-master-key
```

### In Kubernetes
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: litellm-app
  template:
    metadata:
      labels:
        app: litellm-app
    spec:
      containers:
      - name: litellm
        image: chasedecr.dkr.ecr.us-east-1.amazonaws.com/litellm-guardrails:latest
        ports:
        - containerPort: 4000
        env:
        - name: LITELLM_MASTER_KEY
          valueFrom:
            secretKeyRef:
              name: litellm-secrets
              key: master-key
```

## 🔑 ECR Access

To pull these images:

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin chasedecr.dkr.ecr.us-east-1.amazonaws.com

# Pull images
docker pull chasedecr.dkr.ecr.us-east-1.amazonaws.com/litellm-guardrails:latest
```

## 📊 Build Information

Each build includes:
- **Commit SHA**: Traceable to source code
- **Build timestamp**: When the image was created  
- **Multi-platform support**: Works on Intel and ARM architectures
- **Security scanning**: Automated vulnerability assessment
- **Health checks**: Built-in monitoring capabilities

## 🤝 Contributing

This repository focuses on container image building and ECR publishing. For feature requests or issues:

1. Open an issue describing the problem or enhancement
2. Submit a pull request with your changes
3. Ensure all builds pass before merging

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built for infrastructure deployment. Optimized for production. Secured by design.** 🚀