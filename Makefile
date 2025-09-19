# LiteLLM Local Development
# Simple single-service deployment with regex-based PII guardrails

.PHONY: help build start stop clean test test-guardrails logs status pull-model
.DEFAULT_GOAL := help

# Colors
YELLOW := \033[1;33m
GREEN := \033[0;32m
BLUE := \033[0;34m
NC := \033[0m

## Show available commands
help:
	@echo "$(GREEN)LiteLLM Local Development$(NC)"
	@echo "================================="
	@echo ""
	@echo "$(BLUE)Essential Commands:$(NC)"
	@echo "  $(YELLOW)build$(NC)           Build LiteLLM Docker service"
	@echo "  $(YELLOW)start$(NC)           Start LiteLLM service"
	@echo "  $(YELLOW)stop$(NC)            Stop LiteLLM service"
	@echo "  $(YELLOW)restart$(NC)         Restart LiteLLM service"
	@echo "  $(YELLOW)clean$(NC)           Stop and remove container/volumes"
	@echo "  $(YELLOW)test$(NC)            Test LiteLLM functionality"
	@echo "  $(YELLOW)test-guardrails$(NC) Test regex-based PII guardrails"
	@echo "  $(YELLOW)pull-model$(NC)      Pull Ollama model (llama3.2:3b)"
	@echo "  $(YELLOW)logs$(NC)            View container logs"
	@echo "  $(YELLOW)status$(NC)          Show container status"
	@echo ""
	@echo "$(BLUE)Quick Start:$(NC)"
	@echo "1. Build service: make build"
	@echo "2. Start service: make start"
	@echo "3. Test: make test-guardrails"
	@echo ""
	@echo "$(BLUE)Services:$(NC)"
	@echo "  • LiteLLM Proxy: http://localhost:4000"
	@echo "  • Ollama:        http://localhost:11434"
	@echo "  • PostgreSQL:    localhost:5432 (litellm_db)"
	@echo "  • Master Key:    sk-local-dev-key-12345"
	@echo ""

## Build LiteLLM Docker service
build:
	@echo "$(BLUE)Building LiteLLM service...$(NC)"
	docker compose build
	@echo "$(GREEN)LiteLLM service built!$(NC)"

## Start all services
start:
	@echo "$(BLUE)Starting services (PostgreSQL + Ollama + LiteLLM)...$(NC)"
	docker compose up -d
	@echo "$(GREEN)Services started!$(NC)"
	@echo "$(BLUE)LiteLLM UI: http://localhost:4000$(NC)"
	@echo "$(BLUE)Ollama API: http://localhost:11434$(NC)"
	@echo "$(BLUE)PostgreSQL: localhost:5432 (litellm_db)$(NC)"
	@echo "$(YELLOW)Note: You may need to pull the Ollama model manually: docker exec ollama-dev ollama pull llama3.2:3b$(NC)"

## Stop LiteLLM service
stop:
	@echo "$(BLUE)Stopping LiteLLM service...$(NC)"
	docker compose down
	@echo "$(GREEN)LiteLLM service stopped$(NC)"

## Restart LiteLLM service
restart: stop start

## Clean up everything
clean:
	@echo "$(BLUE)Cleaning up service and volumes...$(NC)"
	docker compose down -v
	docker system prune -f 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete$(NC)"

## Test LiteLLM functionality
test:
	@echo "$(BLUE)Testing LiteLLM functionality...$(NC)"
	@echo "1. Health check..." && \
	curl -s -H "Authorization: Bearer sk-local-dev-key-12345" http://localhost:4000/health | python3 -c "import sys,json; data=json.load(sys.stdin); print('✅ LiteLLM healthy' if data.get('status') == 'healthy' else '❌ LiteLLM issue:', data)" && \
	echo "2. Models endpoint..." && \
	curl -s -H "Authorization: Bearer sk-local-dev-key-12345" http://localhost:4000/v1/models | python3 -c "import sys,json; data=json.load(sys.stdin); print('✅ Models endpoint available:', len(data.get('data', [])))"

## Test regex-based guardrail system
test-guardrails:
	@echo "$(BLUE)Testing Regex-based PII Guardrails...$(NC)"
	@echo "" && \
	echo "=== BASELINE (No Guardrail) ===" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer sk-local-dev-key-12345" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "My email is test@example.com"}], "max_tokens": 5}' | \
	python3 -c "import sys,json; print('✅ ALLOWED (no protection)' if 'choices' in json.load(sys.stdin) else '❌ Unexpected block')" && \
	echo "" && \
	echo "=== REGEX PRE-CALL GUARDRAIL ===" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer sk-local-dev-key-12345" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "My email is test@example.com"}], "extra_body": {"guardrails": ["pii-regex-precall"]}, "max_tokens": 5}' | \
	python3 -c "import sys,json; print('✅ BLOCKED (regex detected email)' if 'error' in json.load(sys.stdin) else '❌ Regex failed')" && \
	echo "" && \
	echo "=== REGEX POST-CALL GUARDRAIL ===" && \
	echo "Testing post-call detection (blocks PII in model responses)" && \
	echo "" && \
	echo "=== EMAIL DETECTION ===" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer sk-local-dev-key-12345" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "My contact info includes john.doe@company.com"}], "extra_body": {"guardrails": ["pii-regex-precall"]}, "max_tokens": 5}' | \
	python3 -c "import sys,json; print('✅ BLOCKED (email detected)' if 'error' in json.load(sys.stdin) else '❌ Failed')" && \
	echo "" && \
	echo "=== PHONE DETECTION ===" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer sk-local-dev-key-12345" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "Call me at (555) 123-4567"}], "extra_body": {"guardrails": ["pii-regex-precall"]}, "max_tokens": 5}' | \
	python3 -c "import sys,json; print('✅ BLOCKED (phone detected)' if 'error' in json.load(sys.stdin) else '❌ Failed')" && \
	echo "" && \
	echo "=== SSN DETECTION ===" && \
	curl -s -X POST http://localhost:4000/v1/chat/completions \
		-H "Authorization: Bearer sk-local-dev-key-12345" \
		-H "Content-Type: application/json" \
		-d '{"model": "llama3.2-3b", "messages": [{"role": "user", "content": "My SSN is 123-45-6789"}], "extra_body": {"guardrails": ["pii-regex-precall"]}, "max_tokens": 5}' | \
	python3 -c "import sys,json; print('✅ BLOCKED (SSN detected)' if 'error' in json.load(sys.stdin) else '❌ Failed')"

## View container logs
logs:
	@echo "$(BLUE)Container logs:$(NC)"
	docker compose logs -f

## Pull Ollama model
pull-model:
	@echo "$(BLUE)Pulling Ollama model (llama3.2:3b)...$(NC)"
	docker exec ollama-dev ollama pull llama3.2:3b
	@echo "$(GREEN)Model pulled successfully!$(NC)"

## Show container status
status:
	@echo "$(BLUE)Service Status:$(NC)"
	docker compose ps
	@echo ""
	@echo "$(BLUE)Service Health:$(NC)"
	@curl -s http://localhost:4000/health 2>/dev/null | python3 -c "import sys,json; data=json.load(sys.stdin); print('LiteLLM:', data.get('status', 'unknown'))" || echo "LiteLLM: Not responding"
	@curl -s http://localhost:11434 2>/dev/null | python3 -c "import sys; print('Ollama: Running')" || echo "Ollama: Not responding"