# LiteLLM + Presidio PII Guardrail Stack
# Complete docker-compose deployment with dual guardrail system

.PHONY: help build start stop clean test test-guardrails logs status
.DEFAULT_GOAL := help

# Colors
YELLOW := \033[1;33m
GREEN := \033[0;32m
BLUE := \033[0;34m
NC := \033[0m

## Show available commands
help:
	@echo "$(GREEN)LiteLLM + Presidio PII Guardrail Stack$(NC)"
	@echo "================================================"
	@echo ""
	@echo "$(BLUE)Essential Commands:$(NC)"
	@echo "  $(YELLOW)build$(NC)           Build all Docker services"
	@echo "  $(YELLOW)start$(NC)           Start all services (Presidio + LiteLLM)"
	@echo "  $(YELLOW)stop$(NC)            Stop all services"
	@echo "  $(YELLOW)restart$(NC)         Restart all services"
	@echo "  $(YELLOW)clean$(NC)           Stop and remove all containers/volumes"
	@echo "  $(YELLOW)test$(NC)            Test LiteLLM functionality"
	@echo "  $(YELLOW)test-guardrails$(NC) Test both regex and Presidio guardrails"
	@echo "  $(YELLOW)logs$(NC)            View all container logs"
	@echo "  $(YELLOW)status$(NC)          Show all container status"
	@echo ""
	@echo "$(BLUE)Quick Start:$(NC)"
	@echo "1. Ensure Ollama is running: ollama serve"
	@echo "2. Build services: make build"
	@echo "3. Start stack: make start"
	@echo "4. Test: make test-guardrails"
	@echo ""
	@echo "$(BLUE)Services:$(NC)"
	@echo "  • LiteLLM Proxy:        http://localhost:4000"
	@echo "  • Presidio Analyzer:    http://localhost:3000"
	@echo "  • Presidio Anonymizer:  http://localhost:3001"
	@echo ""

## Build all Docker services
build:
	@echo "$(BLUE)Building all services...$(NC)"
	@if [ ! -f .env ]; then \
		echo "Creating .env file with default master key..."; \
		echo "LITELLM_MASTER_KEY=sk-local-$$(openssl rand -hex 16)" > .env; \
		echo "PORT=4000" >> .env; \
	fi
	docker compose build
	@echo "$(GREEN)All services built!$(NC)"

## Start all services
start:
	@echo "$(BLUE)Starting all services...$(NC)"
	@if [ ! -f .env ]; then echo "ERROR: Run 'make build' first"; exit 1; fi
	docker compose up -d
	@echo "$(GREEN)All services started!$(NC)"
	@echo "$(BLUE)LiteLLM UI: http://localhost:4000$(NC)"
	@echo "$(BLUE)Presidio Analyzer: http://localhost:3000$(NC)"
	@echo "$(BLUE)Presidio Anonymizer: http://localhost:3001$(NC)"

## Stop all services
stop:
	@echo "$(BLUE)Stopping all services...$(NC)"
	docker-compose down
	@echo "$(GREEN)All services stopped$(NC)"

## Restart all services
restart: stop start

## Clean up everything
clean:
	@echo "$(BLUE)Cleaning up all services and volumes...$(NC)"
	docker compose down -v
	docker system prune -f 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete$(NC)"

## Test LiteLLM functionality
test:
	@echo "$(BLUE)Testing LiteLLM functionality...$(NC)"
	@if [ ! -f .env ]; then echo "ERROR: Run 'make start' first"; exit 1; fi
	@source .env && \
	echo "1. Health check..." && \
	curl -s -H "Authorization: Bearer $$LITELLM_MASTER_KEY" http://localhost:4000/health | python3 -c "import sys,json; data=json.load(sys.stdin); print('✅ LiteLLM healthy:' if 'healthy_count' in data else '❌ LiteLLM issue:', data.get('healthy_count', 'unknown'), 'models')" && \
	echo "2. Models endpoint..." && \
	curl -s -H "Authorization: Bearer $$LITELLM_MASTER_KEY" http://localhost:4000/v1/models | python3 -c "import sys,json; data=json.load(sys.stdin); print('✅ Models available:', [m['id'] for m in data.get('data', [])])" && \
	echo "3. Clean request test..." && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer $$LITELLM_MASTER_KEY" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "What is 2+2?"}], "max_tokens": 5}' | \
	python3 -c "import sys,json; print('✅ Chat works' if 'choices' in json.load(sys.stdin) else '❌ Chat failed')"

## Test both guardrail systems
test-guardrails:
	@echo "$(BLUE)Testing Dual Guardrail System...$(NC)"
	@if [ ! -f .env ]; then echo "ERROR: Run 'make start' first"; exit 1; fi
	@source .env && \
	echo "" && \
	echo "=== BASELINE (No Guardrail) ===" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer $$LITELLM_MASTER_KEY" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "My name is John Smith, email test@example.com, I live in Seattle"}], "max_tokens": 5}' | \
	python3 -c "import sys,json; print('✅ ALLOWED (no protection)' if 'choices' in json.load(sys.stdin) else '❌ Unexpected block')" && \
	echo "" && \
	echo "=== REGEX GUARDRAIL ===" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer $$LITELLM_MASTER_KEY" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "My name is John Smith, email test@example.com, I live in Seattle"}], "guardrails": ["pii-regex"]}' | \
	python3 -c "import sys,json; print('✅ BLOCKED (regex detected email)' if 'error' in json.load(sys.stdin) else '❌ Regex failed')" && \
	echo "" && \
	echo "=== PRESIDIO GUARDRAIL ===" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer $$LITELLM_MASTER_KEY" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "My name is John Smith, email test@example.com, I live in Seattle"}], "guardrails": ["pii-presidio"]}' | \
	python3 -c "import sys,json; print('✅ BLOCKED (presidio detected name+email+location)' if 'error' in json.load(sys.stdin) else '❌ Presidio failed')" && \
	echo "" && \
	echo "=== PRESIDIO ADVANTAGE TEST ===" && \
	echo "Testing person names (regex can't detect):" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer $$LITELLM_MASTER_KEY" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "My name is Sarah Johnson"}], "guardrails": ["pii-regex"]}' | \
	python3 -c "import sys,json; print('Regex: ALLOWED (missed name)' if 'choices' in json.load(sys.stdin) else 'Regex: BLOCKED')" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer $$LITELLM_MASTER_KEY" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "My name is Sarah Johnson"}], "guardrails": ["pii-presidio"]}' | \
	python3 -c "import sys,json; print('Presidio: BLOCKED (detected name)' if 'error' in json.load(sys.stdin) else 'Presidio: ALLOWED')"

## View all container logs
logs:
	@echo "$(BLUE)Container logs:$(NC)"
	docker compose logs -f

## Show all container status
status:
	@echo "$(BLUE)Service Status:$(NC)"
	docker compose ps
	@echo ""
	@echo "$(BLUE)Service Health:$(NC)"
	@curl -s http://localhost:4000/health 2>/dev/null | python3 -c "import sys,json; data=json.load(sys.stdin); print('LiteLLM:', data.get('healthy_count', 0), 'models healthy')" || echo "LiteLLM: Not responding"
	@curl -s http://localhost:3000/health 2>/dev/null | python3 -c "import sys,json; print('Presidio Analyzer:', json.load(sys.stdin).get('status', 'unknown'))" || echo "Presidio Analyzer: Not responding"  
	@curl -s http://localhost:3001/health 2>/dev/null | python3 -c "import sys,json; print('Presidio Anonymizer:', json.load(sys.stdin).get('status', 'unknown'))" || echo "Presidio Anonymizer: Not responding"

## Stop existing standalone containers and clean up
cleanup-standalone:
	@echo "$(BLUE)Cleaning up standalone containers...$(NC)"
	@docker stop litellm-proxy presidio-analyzer presidio-anonymizer 2>/dev/null || true
	@docker rm litellm-proxy presidio-analyzer presidio-anonymizer 2>/dev/null || true
	@echo "$(GREEN)Standalone containers cleaned up$(NC)"