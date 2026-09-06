ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim
ARG PYTHON_VERSION
WORKDIR /app
COPY app.py .
RUN echo "Python version: ${PYTHON_VERSION}" > /app/version.txt
CMD ["python3", "app.py"]
