# LiteLLM with Advanced PII Detection Guardrails

A production-ready LiteLLM deployment featuring **dual PII detection systems** (regex-based + AI-powered) with automated CI/CD pipeline for containerized deployment to AWS ECR.

## 🎯 What This Repository Does

This repository provides a **security-enhanced LiteLLM proxy** that automatically detects and blocks Personally Identifiable Information (PII) in both user inputs and AI model responses, packaged as production-ready container images.

### Key Capabilities
- **🛡️ Dual PII Protection**: Fast regex + comprehensive AI-based detection
- **🔄 Automated CI/CD**: GitHub Actions → ECR → Infrastructure deployment
- **🏗️ Production Ready**: Multi-platform containers with security hardening
- **⚡ Local Development**: Complete development environment with testing tools

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    LiteLLM Proxy Container                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │   Regex-Based   │    │  Presidio AI    │                    │
│  │ PII Guardrails  │    │ PII Guardrails  │                    │
│  │                 │    │                 │                    │
│  │ • Email         │    │ • 50+ Entities  │                    │
│  │ • SSN           │    │ • ML-Powered    │                    │
│  │ • Phone         │    │ • Context-Aware │                    │
│  │ • Credit Cards  │    │ • Confidence    │                    │
│  └─────────────────┘    └─────────────────┘                    │
│                                                                 │
│  Pre-call & Post-call Protection for Complete Coverage         │
└─────────────────────────────────────────────────────────────────┘
```

## 🛡️ PII Detection Systems

### 1. **Regex-Based Guardrails** (Fast & Reliable)
- **Email addresses**: `user@domain.com`, `user+tag@domain.org`
- **Social Security Numbers**: `123-45-6789`, `123 45 6789`, `123456789`
- **Phone numbers**: `(555) 123-4567`, `555-123-4567`, `+1 555 123 4567`
- **Credit card numbers**: Visa, MasterCard, Amex, Discover patterns
- **Performance**: Sub-millisecond detection
- **Use Case**: High-throughput scenarios requiring fast response

### 2. **Microsoft Presidio AI Guardrails** (Comprehensive & Intelligent)
- **50+ PII Entity Types**: PERSON, ORGANIZATION, LOCATION, IP_ADDRESS, etc.
- **Context-Aware Detection**: ML models understand context and nuance
- **Confidence Scoring**: Configurable thresholds (default: 0.7)
- **Multi-language Support**: Extensible language detection
- **Use Case**: Comprehensive protection for sensitive environments

### 3. **Dual Protection Strategy**
- **Pre-call Guardrails**: Block PII in user inputs before reaching AI models
- **Post-call Guardrails**: Block PII in AI responses before reaching users
- **Configurable**: Enable/disable individual guardrails as needed
- **Layered Security**: Multiple detection systems provide comprehensive coverage

## 🚀 CI/CD & Deployment Pipeline

### Automated Container Builds
```yaml
Trigger: Push to main (when code files change)
├── Multi-platform build (amd64/arm64)
├── Security hardening applied
├── Push to ECR with dual tags:
│   ├── latest (development)
│   └── {commit-sha} (production)
└── Trigger infrastructure deployment
```

### Path-Based Build Optimization
Builds **only** trigger when these files change:
- `Dockerfile` (build instructions)
- `litellm-config.yaml` (runtime configuration)
- `pii_*.py` (guardrail implementations)
- `.github/workflows/build-and-push-ecr.yml` (CI/CD pipeline)

Documentation and test changes don't trigger unnecessary builds.

### Repository Dispatch Integration
Automatically triggers infrastructure deployment in `litellm-infra` repository with:
- New container image URI
- Commit SHA for traceability
- Environment targeting (dev/staging/prod)

## 📦 Published Container Images

| Repository | Image URI | Description |
|------------|-----------|-------------|
| **litellm-guardrails** | `{ECR_REGISTRY}/litellm-guardrails:latest` | Latest development build |
| **litellm-guardrails** | `{ECR_REGISTRY}/litellm-guardrails:{sha}` | Production-ready tagged builds |

## 🔧 Local Development

### Quick Start
```bash
# Clone and start development environment
git clone https://github.com/mrcloudchase/litellm-app.git
cd litellm-app

# Build and start all services
make build && make start

# Pull AI model for testing
make pull-model

# Test the deployment
make test
```

### Development Stack
- **LiteLLM Proxy**: http://localhost:4000
- **Ollama (AI Models)**: http://localhost:11434  
- **PostgreSQL**: localhost:5432
- **Master Key**: `sk-local-dev-key-12345`

### Testing Guardrails
```bash
# Test regex-based PII detection
make test-guardrails

# Use HTTP test collections
# tests/test_regex.http - Regex guardrail tests
# tests/test_presidio.http - Presidio guardrail tests
```

## 🔧 Configuration

### Guardrail Configuration (`litellm-config.yaml`)
```yaml
guardrails:
  # Fast regex-based detection
  - guardrail_name: "pii-regex-precall"
    litellm_params:
      guardrail: pii_regex_precall.PIIRegexPreCallGuardrail
      mode: "pre_call"
      
  # Comprehensive AI-based detection  
  - guardrail_name: "pii-presidio-precall"
    litellm_params:
      guardrail: pii_presidio_precall.PIIPresidioPreCallGuardrail
      mode: "pre_call"
      language: "en"
      threshold: 0.7
```

### Environment Variables
```bash
LITELLM_MASTER_KEY=your-master-key    # Authentication
DATABASE_URL=postgresql://...         # Optional: Persistence
LITELLM_MODE=PRODUCTION              # Runtime mode
```

## 🏷️ Production Usage

### Docker Compose
```yaml
version: '3.8'
services:
  litellm:
    image: {ECR_REGISTRY}/litellm-guardrails:latest
    ports:
      - "4000:4000"
    environment:
      - LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
      - DATABASE_URL=${DATABASE_URL}
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm-guardrails
spec:
  replicas: 3
  selector:
    matchLabels:
      app: litellm-guardrails
  template:
    spec:
      containers:
      - name: litellm
        image: {ECR_REGISTRY}/litellm-guardrails:latest
        ports:
        - containerPort: 4000
        env:
        - name: LITELLM_MASTER_KEY
          valueFrom:
            secretKeyRef:
              name: litellm-secrets
              key: master-key
```

## 🔒 Security Features

### Container Security
- **Minimal Attack Surface**: Only essential runtime files included
- **Security Hardening**: Non-root execution where possible
- **Comprehensive .dockerignore**: Test files, docs, and dev tools excluded
- **Multi-platform Support**: Consistent security across architectures

### PII Protection
- **Zero Trust Model**: All inputs and outputs scanned
- **Configurable Sensitivity**: Adjustable confidence thresholds
- **Audit Trail**: Comprehensive logging of PII detection events
- **Performance Optimized**: Fast regex for high-throughput, AI for accuracy

## 📁 Repository Structure

```
litellm-app/
├── Dockerfile                    # Container build instructions
├── litellm-config.yaml          # LiteLLM runtime configuration
├── docker-compose.yml           # Local development stack
├── Makefile                     # Development automation
├── 
├── pii_regex_detection.py       # Shared regex detection logic
├── pii_regex_precall.py         # Regex pre-call guardrail
├── pii_regex_postcall.py        # Regex post-call guardrail
├── 
├── pii_presidio_detection.py    # Shared Presidio AI logic
├── pii_presidio_precall.py      # Presidio pre-call guardrail  
├── pii_presidio_postcall.py     # Presidio post-call guardrail
├── 
├── tests/                       # Test collections and scripts
│   ├── test_regex.http         # Regex guardrail API tests
│   ├── test_presidio.http      # Presidio guardrail API tests
│   └── test_regex.py           # Python test automation
└── 
└── .github/workflows/           # CI/CD automation
    └── build-and-push-ecr.yml  # Container build pipeline
```

## 🚀 Getting Started

1. **For Local Development**: Use `make build && make start`
2. **For Production Deployment**: Pull from ECR and deploy with your infrastructure
3. **For Testing**: Use the HTTP test collections in `tests/`
4. **For CI/CD**: Configure GitHub secrets and let automation handle builds

## 🤝 Contributing

1. Fork the repository
2. Make your changes (ensure they follow the project structure)
3. Test locally with `make test` and `make test-guardrails`
4. Submit a pull request

Changes to core files (`Dockerfile`, `litellm-config.yaml`, `pii_*.py`) will trigger automatic container builds.

---

**Enterprise-grade PII protection for AI applications. Built for scale, security, and reliability.** 🛡️