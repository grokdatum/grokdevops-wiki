FROM python:3.11-slim
ARG APP_VERSION
WORKDIR /app
COPY app.py .
RUN echo "${APP_VERSION}" > version.txt
CMD ["python3", "app.py"]
