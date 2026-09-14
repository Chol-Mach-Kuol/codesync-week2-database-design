#!/bin/bash
set -e
source venv/bin/activate
python -c "from etl.run import export_json; export_json()"
