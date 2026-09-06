FROM python:3.11-slim
WORKDIR /app
COPY server.py .
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s curl -f http://localhost:8080/ || exit 1
CMD ["python3", "server.py"]
