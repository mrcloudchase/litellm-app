#!/bin/bash
# Pull required models for LiteLLM

echo "🔄 Pulling required Ollama models..."

# Wait for Ollama service to be ready
echo "⏳ Waiting for Ollama service to be ready..."
while ! ollama list >/dev/null 2>&1; do
    sleep 2
done

# Pull Llama 3.2 3B model
echo "📦 Pulling llama3.2:3b..."
ollama pull llama3.2:3b

# Pull DeepSeek R1 1.5B model (if available)
echo "📦 Pulling deepseek-r1:1.5b..."
ollama pull deepseek-r1:1.5b || echo "⚠️  DeepSeek R1 model not available, skipping..."

echo "✅ Model pulling complete!"
echo "📋 Available models:"
ollama list
