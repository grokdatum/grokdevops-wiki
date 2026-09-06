FROM python:3.11-slim
RUN useradd --create-home appuser
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN chown -R appuser:appuser /app
USER appuser
HEALTHCHECK --interval=10s --timeout=5s CMD curl -f http://localhost:5000/ || exit 1
CMD ["python3", "app.py"]
