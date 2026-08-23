#!/bin/bash
echo "Starting MCP server in background..."
python mcp_server/server.py &

echo "Starting FastAPI server..."
# Azure App Service sets the PORT environment variable (default 8000)
# We use uvicorn explicitly since it's a FastAPI app
uvicorn app.main:app --host 0.0.0.0 --port $PORT
