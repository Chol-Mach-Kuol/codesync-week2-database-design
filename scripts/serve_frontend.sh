#!/bin/bash
set -e
source venv/bin/activate
uvicorn api.app:app --reload --port 8000
