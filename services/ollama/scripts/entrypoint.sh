#!/bin/bash
# Custom entrypoint for Ollama with automatic model pulling

echo "🚀 Starting Ollama service with model auto-pulling..."

# Start Ollama server in the background
echo "🔧 Starting Ollama server..."
/bin/ollama serve &
OLLAMA_PID=$!

# Wait a moment for the server to start
sleep 5

# Pull models in the background
echo "🔄 Starting model pulling process..."
/app/scripts/pull-models.sh &

# Wait for the Ollama server process
echo "✅ Ollama service ready and pulling models..."
wait $OLLAMA_PID
