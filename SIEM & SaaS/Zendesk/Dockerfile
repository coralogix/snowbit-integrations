FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ship_zendesk_to_coralogix.py run.sh .env.example ./
RUN chmod +x run.sh

# Persist STATE_FILE across restarts, e.g. -v zendesk-state:/app/state
CMD ["python", "ship_zendesk_to_coralogix.py"]
