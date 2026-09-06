FROM python:3.11-slim
RUN useradd --create-home appuser
WORKDIR /app
COPY app.py .
RUN chown -R appuser:appuser /app
USER appuser
CMD ["python3", "app.py"]
