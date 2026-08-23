#!/bin/bash
echo "Starting FastAPI server for Doctor Agents..."
uvicorn main:app --host 0.0.0.0 --port $PORT
