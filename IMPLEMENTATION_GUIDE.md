# Custom Guardrail Implementation Guide

A comprehensive guide for implementing custom PII detection guardrails in LiteLLM using the dual-detection framework (regex-based + AI-powered).

## Overview

This guide demonstrates how to create custom guardrails that integrate with LiteLLM to provide comprehensive PII protection. You'll learn to build both fast regex-based detectors and sophisticated AI-powered guardrails using Microsoft Presidio.

## Architecture Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              LiteLLM Request Flow                               │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            1. User Input Received                              │
│                          "My email is john@company.com"                        │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          2. PRE-CALL GUARDRAILS                                │
│                                                                                 │
│  ┌─────────────────────────┐         ┌─────────────────────────┐               │
│  │    Regex Guardrail      │         │   Presidio Guardrail    │               │
│  │                         │         │                         │               │
│  │  • Fast pattern match   │         │  • ML-based analysis    │               │
│  │  • Email regex check    │    +    │  • Context awareness    │               │
│  │  • Result: PII found    │         │  • Confidence scoring   │               │
│  │  • Action: BLOCK        │         │  • Result: EMAIL_ADDRESS│               │
│  └─────────────────────────┘         └─────────────────────────┘               │
│                                        │                                        │
│                              ┌─────────▼─────────┐                             │
│                              │   PII DETECTED    │                             │
│                              │   REQUEST BLOCKED │                             │
│                              └───────────────────┘                             │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     3. Error Response to User                                  │
│      "Pre-call guardrail blocked PII detected: email, EMAIL_ADDRESS"          │
└─────────────────────────────────────────────────────────────────────────────────┘

                              ═══ CLEAN REQUEST FLOW ═══

┌─────────────────────────────────────────────────────────────────────────────────┐
│                    1. Clean User Input: "Hello, how are you?"                  │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          2. PRE-CALL GUARDRAILS                                │
│                            ✅ No PII Detected                                   │
│                            ✅ Request Allowed                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          3. AI Model Processing                                │
│                    "I'm doing well, thank you for asking!"                     │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         4. POST-CALL GUARDRAILS                                │
│                            ✅ No PII Detected                                   │
│                            ✅ Response Allowed                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      5. Clean Response to User                                 │
│                    "I'm doing well, thank you for asking!"                     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Implementation Guide

### Step 1: Understanding the Guardrail Framework

#### Core Components
```python
# Base class from LiteLLM
from litellm.integrations.custom_guardrail import CustomGuardrail

# Your custom guardrail inherits from this base
class MyCustomGuardrail(CustomGuardrail):
    def __init__(self, **kwargs):
        # Initialize your detection logic
        pass
    
    async def async_pre_call_hook(self, ...):
        # Process user input before AI model
        pass
    
    async def async_post_call_success_hook(self, ...):
        # Process AI response before user
        pass
```

#### Detection Logic Separation
```python
# Shared detection logic (recommended pattern)
class MyDetectionEngine:
    def __init__(self):
        # Initialize detection models/patterns
        pass
    
    def detect_pii(self, text: str) -> bool:
        # Your detection logic here
        pass

# Guardrail classes use the shared engine
class MyPreCallGuardrail(CustomGuardrail):
    def __init__(self, **kwargs):
        self.detector = MyDetectionEngine()
```

### Step 2: Implementing Regex-Based Detection

#### Create Detection Engine (`my_detection.py`)
```python
import re
from typing import List, Dict

class MyPIIDetection:
    def __init__(self):
        # Define your PII patterns
        self.patterns = {
            'email': re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
            'ssn': re.compile(r'\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b'),
            'phone': re.compile(r'\b\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\b'),
            # Add your custom patterns here
        }
    
    def detect_pii(self, text: str) -> Dict[str, List[str]]:
        """Detect PII in text and return findings"""
        detected = {}
        for pii_type, pattern in self.patterns.items():
            matches = pattern.findall(text)
            if matches:
                detected[pii_type] = matches
        return detected
    
    def has_pii(self, text: str) -> bool:
        """Quick check if text contains any PII"""
        return bool(self.detect_pii(text))
```

#### Create Pre-Call Guardrail (`my_precall.py`)
```python
from typing import Optional, Union, Literal
from litellm._logging import verbose_proxy_logger
from litellm.caching.caching import DualCache
from litellm.integrations.custom_guardrail import CustomGuardrail
from litellm.proxy._types import UserAPIKeyAuth
from my_detection import MyPIIDetection

class MyPreCallGuardrail(CustomGuardrail):
    def __init__(self, **kwargs):
        self.detector = MyPIIDetection()
        self.block_on_detection = kwargs.get("block_on_detection", True)
        super().__init__(**kwargs)
    
    async def async_pre_call_hook(
        self,
        user_api_key_dict: UserAPIKeyAuth,
        cache: DualCache,
        data: dict,
        call_type: Literal["completion", "embedding", "image_generation", "moderation", "audio_transcription"],
    ) -> Optional[dict]:
        """Process user input before AI model"""
        
        # Extract user messages
        messages = data.get("messages", [])
        user_content = ""
        
        for message in messages:
            if message.get("role") == "user":
                user_content += message.get("content", "") + " "
        
        # Detect PII
        detected_pii = self.detector.detect_pii(user_content)
        
        if detected_pii and self.block_on_detection:
            pii_types = list(detected_pii.keys())
            verbose_proxy_logger.warning(f"Pre-call guardrail blocked PII: {pii_types}")
            
            # Block the request
            raise Exception(f"Pre-call guardrail blocked PII detected: {', '.join(pii_types)}")
        
        # Allow request to proceed
        return None
```

#### Create Post-Call Guardrail (`my_postcall.py`)
```python
import litellm
from litellm._logging import verbose_proxy_logger
from litellm.integrations.custom_guardrail import CustomGuardrail
from litellm.proxy._types import UserAPIKeyAuth
from my_detection import MyPIIDetection

class MyPostCallGuardrail(CustomGuardrail):
    def __init__(self, **kwargs):
        self.detector = MyPIIDetection()
        self.block_on_detection = kwargs.get("block_on_detection", True)
        super().__init__(**kwargs)
    
    async def async_post_call_success_hook(
        self,
        data: dict,
        user_api_key_dict: UserAPIKeyAuth,
        response,
    ):
        """Process AI response before user"""
        
        # Extract response content
        if hasattr(response, 'choices') and response.choices:
            for choice_idx, choice in enumerate(response.choices):
                if hasattr(choice, 'message') and hasattr(choice.message, 'content'):
                    content = choice.message.content
                    
                    # Detect PII in response
                    detected_pii = self.detector.detect_pii(content)
                    
                    if detected_pii and self.block_on_detection:
                        pii_types = list(detected_pii.keys())
                        verbose_proxy_logger.warning(f"Post-call guardrail blocked PII: {pii_types}")
                        
                        # Block the response
                        raise Exception(f"Post-call guardrail blocked PII detected: {', '.join(pii_types)}")
        
        # Allow response to proceed
        return response
```

### Step 3: Advanced AI-Based Detection (Presidio Integration)

#### Enhanced Detection Engine (`my_ai_detection.py`)
```python
from typing import List, Dict
from presidio_analyzer import AnalyzerEngine
from presidio_analyzer.nlp_engine import NlpEngineProvider

class MyAIDetection:
    def __init__(self, language: str = "en", threshold: float = 0.7):
        self.language = language
        self.threshold = threshold
        
        # Initialize Presidio analyzer
        try:
            # Use spaCy model for better accuracy
            nlp_config = {
                "nlp_engine_name": "spacy",
                "models": [{"lang_code": "en", "model_name": "en_core_web_sm"}]
            }
            nlp_engine = NlpEngineProvider(nlp_configuration=nlp_config).create_engine()
            self.analyzer = AnalyzerEngine(nlp_engine=nlp_engine)
        except Exception as e:
            # Fallback to default
            print(f"Using default Presidio configuration: {e}")
            self.analyzer = AnalyzerEngine()
        
        # Define entities to detect (customize as needed)
        self.entities = [
            "PERSON", "EMAIL_ADDRESS", "PHONE_NUMBER", "ORGANIZATION",
            "LOCATION", "IP_ADDRESS", "CREDIT_CARD", "US_SSN",
            "US_PASSPORT", "US_DRIVER_LICENSE", "MEDICAL_LICENSE",
            "URL", "CRYPTO", "IBAN_CODE", "DATE_TIME"
        ]
    
    def detect_pii(self, text: str) -> Dict[str, List[Dict]]:
        """Detect PII using AI analysis"""
        if not text or not text.strip():
            return {}
        
        try:
            # Analyze text
            results = self.analyzer.analyze(
                text=text,
                entities=self.entities,
                language=self.language
            )
            
            # Filter by confidence threshold
            filtered_results = [r for r in results if r.score >= self.threshold]
            
            # Group by entity type
            detected = {}
            for result in filtered_results:
                entity_type = result.entity_type
                if entity_type not in detected:
                    detected[entity_type] = []
                
                detected[entity_type].append({
                    "text": text[result.start:result.end],
                    "confidence": result.score,
                    "start": result.start,
                    "end": result.end
                })
            
            return detected
            
        except Exception as e:
            print(f"Error in AI PII detection: {e}")
            return {}
    
    def has_pii(self, text: str) -> bool:
        """Quick check if text contains PII above threshold"""
        return bool(self.detect_pii(text))
```

### Step 4: Configuration Integration

#### Add to `litellm-config.yaml`
```yaml
# Custom Guardrails Configuration
guardrails:
  # Your regex-based guardrail
  - guardrail_name: "my-regex-precall"
    litellm_params:
      guardrail: my_precall.MyPreCallGuardrail
      mode: "pre_call"
      block_on_detection: true
      
  - guardrail_name: "my-regex-postcall"
    litellm_params:
      guardrail: my_postcall.MyPostCallGuardrail
      mode: "post_call"
      block_on_detection: true
  
  # Your AI-powered guardrail
  - guardrail_name: "my-ai-precall"
    litellm_params:
      guardrail: my_ai_precall.MyAIPreCallGuardrail
      mode: "pre_call"
      language: "en"
      threshold: 0.7
      entities: ["PERSON", "EMAIL_ADDRESS", "ORGANIZATION"]
```

### Step 5: Container Integration

#### Update `Dockerfile`
```dockerfile
FROM ghcr.io/berriai/litellm:main-stable

WORKDIR /app

# Install your dependencies (if using AI detection)
RUN pip install --no-cache-dir --quiet presidio-analyzer

# Copy your guardrail files
COPY litellm-config.yaml /app/litellm-config.yaml
COPY my_detection.py /app/my_detection.py
COPY my_precall.py /app/my_precall.py
COPY my_postcall.py /app/my_postcall.py
COPY my_ai_detection.py /app/my_ai_detection.py
COPY my_ai_precall.py /app/my_ai_precall.py

# Set environment and expose port
ENV LITELLM_MODE=PRODUCTION
EXPOSE 4000

# Health check that accepts 401 (auth required)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/health | grep -E "^(200|401)$" > /dev/null || exit 1

CMD ["--port", "4000", "--config", "/app/litellm-config.yaml"]
```

## Testing Your Implementation

### Create Test Collection (`test_my_guardrails.http`)
```http
### Test Setup
@baseUrl = http://localhost:4000
@masterKey = your-master-key
@model = your-model

### Test 1: Baseline (no guardrail)
POST {{baseUrl}}/v1/chat/completions
Authorization: Bearer {{masterKey}}
Content-Type: application/json

{
  "model": "{{model}}",
  "messages": [{"role": "user", "content": "My email is test@example.com"}],
  "max_tokens": 10
}

### Test 2: With your regex guardrail
POST {{baseUrl}}/v1/chat/completions
Authorization: Bearer {{masterKey}}
Content-Type: application/json

{
  "model": "{{model}}",
  "messages": [{"role": "user", "content": "My email is test@example.com"}],
  "guardrails": ["my-regex-precall"],
  "max_tokens": 10
}

### Test 3: With your AI guardrail
POST {{baseUrl}}/v1/chat/completions
Authorization: Bearer {{masterKey}}
Content-Type: application/json

{
  "model": "{{model}}",
  "messages": [{"role": "user", "content": "My name is John Smith and I work at Microsoft"}],
  "guardrails": ["my-ai-precall"],
  "max_tokens": 10
}
```

## Advanced Implementation Patterns

### Pattern 1: Configurable Detection Thresholds
```python
class ConfigurableGuardrail(CustomGuardrail):
    def __init__(self, **kwargs):
        # Allow runtime configuration
        self.email_detection = kwargs.get("detect_emails", True)
        self.phone_detection = kwargs.get("detect_phones", True)
        self.confidence_threshold = kwargs.get("threshold", 0.7)
        
        # Initialize detection with configuration
        self.detector = MyDetection(
            email_enabled=self.email_detection,
            phone_enabled=self.phone_detection,
            threshold=self.confidence_threshold
        )
```

### Pattern 2: Logging and Monitoring
```python
async def async_pre_call_hook(self, ...):
    detected_pii = self.detector.detect_pii(user_content)
    
    if detected_pii:
        # Log detection event
        verbose_proxy_logger.warning(
            f"PII detected: {list(detected_pii.keys())} "
            f"in request from user {user_api_key_dict.user_id}"
        )
        
        # Could send to monitoring system
        # self.send_security_alert(detected_pii, user_api_key_dict)
        
        if self.block_on_detection:
            raise Exception(f"PII detected: {', '.join(detected_pii.keys())}")
```

### Pattern 3: Allowlist/Bypass Logic
```python
def should_bypass_detection(self, user_api_key_dict: UserAPIKeyAuth) -> bool:
    """Allow certain users/roles to bypass PII detection"""
    
    # Admin users bypass
    if user_api_key_dict.user_role == "admin":
        return True
    
    # Test environment bypass
    if os.getenv("ENVIRONMENT") == "test":
        return True
    
    # Specific user allowlist
    allowed_users = ["test-user-id", "admin-user-id"]
    if user_api_key_dict.user_id in allowed_users:
        return True
    
    return False
```

## Deployment Integration

### Local Development
```bash
# 1. Create your guardrail files
touch my_detection.py my_precall.py my_postcall.py

# 2. Update litellm-config.yaml with your guardrails

# 3. Build and test
docker build -t my-litellm-guardrails .
docker run -p 4000:4000 my-litellm-guardrails

# 4. Test your implementation
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer your-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "your-model", "messages": [{"role": "user", "content": "test@example.com"}], "guardrails": ["my-regex-precall"]}'
```

### Production Deployment
```yaml
# docker-compose.yml
version: '3.8'
services:
  litellm:
    build: .
    ports:
      - "4000:4000"
    environment:
      - LITELLM_MASTER_KEY=${MASTER_KEY}
      - LITELLM_MODE=PRODUCTION
```

## Best Practices

### 1. **Performance Optimization**
- Use **regex for fast detection** of simple patterns
- Use **AI models for complex/contextual** detection
- **Cache detection results** when possible
- **Fail fast** on obvious PII patterns

### 2. **Error Handling**
```python
try:
    detected_pii = self.detector.detect_pii(text)
except Exception as e:
    verbose_proxy_logger.error(f"Detection error: {e}")
    # Decide: fail open (allow) or fail closed (block)
    if self.fail_closed_on_error:
        raise Exception("PII detection failed, blocking request")
    return None  # Allow request to proceed
```

### 3. **Configuration Management**
```python
def __init__(self, **kwargs):
    # Provide sensible defaults
    self.threshold = kwargs.get("threshold", 0.7)
    self.entities = kwargs.get("entities", self.default_entities)
    self.block_mode = kwargs.get("block_on_detection", True)
    
    # Validate configuration
    if not 0.0 <= self.threshold <= 1.0:
        raise ValueError("Threshold must be between 0.0 and 1.0")
```

### 4. **Testing Strategy**
```python
# Create comprehensive test cases
test_cases = [
    {"input": "My email is test@example.com", "should_block": True, "reason": "email"},
    {"input": "Call me at 555-123-4567", "should_block": True, "reason": "phone"},
    {"input": "Hello, how are you?", "should_block": False, "reason": "clean"},
    {"input": "My name is John Smith", "should_block": True, "reason": "person"},
]

for case in test_cases:
    result = detector.has_pii(case["input"])
    assert result == case["should_block"], f"Failed: {case['reason']}"
```

## Implementation Checklist

### Core Requirements:
- [ ] **Detection Engine**: Shared logic class with PII patterns/models
- [ ] **Pre-Call Guardrail**: Inherits from CustomGuardrail, implements async_pre_call_hook
- [ ] **Post-Call Guardrail**: Inherits from CustomGuardrail, implements async_post_call_success_hook  
- [ ] **Configuration**: Added to litellm-config.yaml guardrails section
- [ ] **Container Integration**: Files copied in Dockerfile, dependencies installed
- [ ] **Testing**: HTTP test collection with positive/negative cases

### Advanced Features:
- [ ] **AI Integration**: Presidio or similar ML-based detection
- [ ] **Configurable Thresholds**: Runtime configuration via kwargs
- [ ] **Logging**: Proper security event logging
- [ ] **Error Handling**: Graceful failure modes
- [ ] **Performance**: Optimized for production workloads
- [ ] **Monitoring**: Integration with observability systems

## Example: Complete Custom Credit Card Guardrail

Here's a complete example implementing credit card detection:

```python
# credit_card_detection.py
import re
from typing import Dict, List

class CreditCardDetection:
    def __init__(self):
        self.patterns = {
            'visa': re.compile(r'\b4[0-9]{12}(?:[0-9]{3})?\b'),
            'mastercard': re.compile(r'\b5[1-5][0-9]{14}\b'),
            'amex': re.compile(r'\b3[47][0-9]{13}\b'),
            'discover': re.compile(r'\b6(?:011|5[0-9]{2})[0-9]{12}\b')
        }
    
    def detect_credit_cards(self, text: str) -> Dict[str, List[str]]:
        detected = {}
        for card_type, pattern in self.patterns.items():
            matches = pattern.findall(text)
            if matches:
                detected[card_type] = matches
        return detected
    
    def has_credit_cards(self, text: str) -> bool:
        return bool(self.detect_credit_cards(text))

# credit_card_guardrail.py
from litellm.integrations.custom_guardrail import CustomGuardrail
from credit_card_detection import CreditCardDetection

class CreditCardGuardrail(CustomGuardrail):
    def __init__(self, **kwargs):
        self.detector = CreditCardDetection()
        super().__init__(**kwargs)
    
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        # Extract user messages
        user_content = ""
        for message in data.get("messages", []):
            if message.get("role") == "user":
                user_content += message.get("content", "") + " "
        
        # Check for credit cards
        if self.detector.has_credit_cards(user_content):
            detected = self.detector.detect_credit_cards(user_content)
            card_types = list(detected.keys())
            raise Exception(f"Credit card detected: {', '.join(card_types)}")
        
        return None
```

## Integration with Your Framework

To integrate with the existing dual-detection system:

1. **Follow the established patterns** in `pii_regex_*` and `pii_presidio_*` files
2. **Use the shared detection approach** with separate engine classes
3. **Add to the existing configuration** in `litellm-config.yaml`
4. **Create comprehensive tests** following the `test_*.http` pattern
5. **Document in README.md** following the established format

## Summary

This implementation guide provides:
- **Complete code examples** for both regex and AI-based detection
- **Step-by-step integration** with LiteLLM
- **Production-ready patterns** with error handling and logging
- **Testing strategies** for validation
- **Architecture diagrams** showing request flow
- **Best practices** for performance and security

You now have everything needed to implement custom guardrails that integrate seamlessly with the existing dual-detection framework!
