# LiteLLM PII Guardrails Architecture

Detailed architecture documentation for the dual PII detection system implemented in this repository.

## High-Level System Architecture

```mermaid
graph TB
    subgraph "External Layer"
        Client[External Client<br/>Web UI, API Client, etc.]
    end
    
    subgraph "AWS Infrastructure"
        ALB[Application Load Balancer<br/>litellm-dev-ci-alb-26395982]
        
        subgraph "ECS Service"
            subgraph "Container Instance"
                subgraph "LiteLLM Proxy"
                    Core[LiteLLM Core<br/>Port 4000]
                    
                    subgraph "Guardrail Framework"
                        subgraph "Detection Engines"
                            Regex[Regex Engine<br/>• Email patterns<br/>• SSN patterns<br/>• Phone patterns<br/>• Credit card patterns]
                            Presidio[Presidio AI Engine<br/>• 50+ entity types<br/>• ML analysis<br/>• Confidence scoring<br/>• Context awareness]
                        end
                        
                        subgraph "Guardrail Types"
                            PreCall[Pre-Call Guardrails<br/>• Block input PII<br/>• Fast regex check<br/>• AI analysis]
                            PostCall[Post-Call Guardrails<br/>• Block output PII<br/>• Response scanning<br/>• Content filtering]
                        end
                    end
                end
            end
        end
        
        RDS[(RDS PostgreSQL<br/>Database)]
    end
    
    subgraph "External AI Models"
        OpenAI[OpenAI Models]
        Anthropic[Anthropic Models]
        Ollama[Local Ollama]
        Other[Other Providers]
    end
    
    Client -->|HTTP Request| ALB
    ALB -->|Route to ECS| Core
    Core --> Regex
    Core --> Presidio
    Regex --> PreCall
    Presidio --> PreCall
    PreCall --> PostCall
    PostCall --> Core
    Core -->|External API Calls| OpenAI
    Core -->|External API Calls| Anthropic
    Core -->|Local Development| Ollama
    Core -->|External API Calls| Other
    Core -->|Persistence| RDS
    
    style Client fill:#e1f5fe
    style ALB fill:#fff3e0
    style Core fill:#e8f5e8
    style Regex fill:#f3e5f5
    style Presidio fill:#e8eaf6
    style PreCall fill:#ffebee
    style PostCall fill:#ffebee
    style RDS fill:#e0f2f1
```

## Request Processing Flow

### Pre-Call Guardrail Flow
```mermaid
flowchart TD
    A[User Request] --> B[Authentication Check<br/>Master Key Validation]
    B -->|Authenticated| C[Extract User Messages<br/>Parse request content]
    B -->|Invalid| Z[401 Unauthorized]
    
    C --> D[Regex Detection]
    C --> E[Presidio AI Analysis]
    
    D --> F[Email Pattern Matching<br/>SSN Format Detection<br/>Phone Number Patterns<br/>Credit Card Validation]
    E --> G[Load ML Models spaCy<br/>Context-aware Analysis<br/>50+ Entity Detection<br/>Confidence Scoring ≥0.7]
    
    F --> H{PII Found?}
    G --> I{PII Found?}
    
    H -->|Yes| J[Block Request<br/>Log Detection Event<br/>Return Error Response]
    I -->|Yes| J
    H -->|No| K{All Guardrails Passed?}
    I -->|No| K
    
    K -->|Yes| L[Forward to AI Model<br/>OpenAI, Anthropic, etc.]
    
    style A fill:#e1f5fe
    style B fill:#fff3e0
    style C fill:#e8f5e8
    style D fill:#f3e5f5
    style E fill:#e8eaf6
    style J fill:#ffebee
    style L fill:#e8f5e8
```

### Post-Call Guardrail Flow
```mermaid
flowchart TD
    A[AI Model Response] --> B[Extract Response Content<br/>Parse AI model output]
    
    B --> C[Regex Detection]
    B --> D[Presidio AI Analysis]
    
    C --> E[Scan Response for PII Patterns<br/>Check for Leaked Information]
    D --> F[ML-based Response Analysis<br/>Context Understanding<br/>Entity Confidence Scoring]
    
    E --> G{PII Found in Response?}
    F --> H{PII Found in Response?}
    
    G -->|Yes| I[Block Response<br/>Log PII Detection<br/>Return Error Message]
    H -->|Yes| I
    G -->|No| J{All Post-Call Checks Passed?}
    H -->|No| J
    
    J -->|Yes| K[Return Clean Response to User]
    
    style A fill:#fff3e0
    style B fill:#e8f5e8
    style C fill:#f3e5f5
    style D fill:#e8eaf6
    style I fill:#ffebee
    style K fill:#e8f5e8
```

## Code Architecture

### Class Hierarchy
```
CustomGuardrail (LiteLLM Base Class)
├── PIIRegexPreCallGuardrail
├── PIIRegexPostCallGuardrail  
├── PIIPresidioPreCallGuardrail
└── PIIPresidioPostCallGuardrail

Detection Engines (Shared Logic)
├── PIIRegexDetection
│   ├── email_pattern
│   ├── ssn_pattern
│   ├── phone_pattern
│   └── credit_card_pattern
└── PIIPresidioDetection
    ├── analyzer (AnalyzerEngine)
    ├── entities (50+ types)
    └── confidence_threshold
```

### File Organization
```
litellm-app/
├── Dockerfile                          # Container build with dependencies
├── litellm-config.yaml                 # Guardrail configuration
│
├── pii_regex_detection.py              # Shared regex patterns
├── pii_regex_precall.py                # Regex pre-call guardrail
├── pii_regex_postcall.py               # Regex post-call guardrail
│
├── pii_presidio_detection.py           # Shared AI detection logic
├── pii_presidio_precall.py             # Presidio pre-call guardrail
├── pii_presidio_postcall.py            # Presidio post-call guardrail
│
└── tests/                              # Comprehensive test collections
    ├── test_regex.http                 # Regex guardrail tests
    ├── test_presidio.http              # Presidio guardrail tests
    └── test_regex.py                   # Automated Python tests
```

## Configuration Architecture

### Guardrail Registration
```yaml
# litellm-config.yaml
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
      block_on_detection: true
```

### Runtime Activation
```bash
# API request with specific guardrails
curl -X POST /v1/chat/completions \
  -H "Authorization: Bearer key" \
  -d '{
    "model": "llama3.2-3b",
    "messages": [{"role": "user", "content": "test@example.com"}],
    "guardrails": ["pii-regex-precall", "pii-presidio-precall"]
  }'
```

## Deployment Architecture

### Development Environment
```
Docker Compose Stack:
├── LiteLLM Container (with embedded guardrails)
├── Ollama Container (local AI models)
├── PostgreSQL Container (persistence)
└── Shared Network (inter-service communication)
```

### Production Environment  
```
AWS Infrastructure:
├── Application Load Balancer (public endpoint)
├── ECS Service (auto-scaling containers)
│   └── LiteLLM Tasks (embedded guardrails)
├── RDS PostgreSQL (managed database)
└── ECR Registry (container images)
```

### CI/CD Pipeline
```
GitHub Repository → GitHub Actions → ECR Registry → Repository Dispatch → Infrastructure Deployment

litellm-app repo:
├── Code changes detected (path-based triggering)
├── Multi-platform container build (amd64/arm64)
├── Security scanning and testing
├── Push to ECR with dual tags (latest + commit-sha)
└── Trigger infrastructure deployment

litellm-infra repo:
├── Receive repository dispatch event
├── Extract new container image URI
├── Update Terraform configuration
├── Deploy to ECS with zero-downtime
└── Verify deployment health
```

## Security Architecture

### Container Security
```
Security Layers:
├── Minimal base image (LiteLLM official)
├── Non-root execution (where possible)
├── Comprehensive .dockerignore (test/doc exclusion)
├── Health checks (200/401 acceptance)
├── Multi-platform builds (consistent security)
└── Dependency scanning (automated)
```

### PII Protection Layers
```
Defense in Depth:
├── Input Validation (pre-call guardrails)
├── Output Filtering (post-call guardrails)  
├── Dual Detection (regex + AI)
├── Configurable Sensitivity (confidence thresholds)
├── Audit Logging (security events)
└── Fail-Safe Blocking (default deny)
```

## Performance Characteristics

### Regex Guardrails
- **Latency**: Sub-millisecond detection
- **Throughput**: High (minimal CPU overhead)
- **Accuracy**: High for known patterns
- **Use Case**: High-volume, performance-critical applications

### Presidio AI Guardrails  
- **Latency**: ~10-50ms additional processing
- **Throughput**: Moderate (ML model overhead)
- **Accuracy**: Very high with context awareness
- **Use Case**: Security-critical applications requiring comprehensive coverage

### Combined System
- **Layered Protection**: Fast regex + comprehensive AI
- **Configurable**: Enable/disable individual guardrails
- **Scalable**: ECS auto-scaling based on demand
- **Monitored**: Health checks and error tracking