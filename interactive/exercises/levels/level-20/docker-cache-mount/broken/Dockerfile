# syntax=docker/dockerfile:1
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/tmp/pip-cache pip install --cache-dir /root/.cache/pip -r requirements.txt
COPY app.py .
CMD ["python3", "app.py"]
