FROM ubuntu:22.04
RUN apt-get update && \
    apt-get install -y curl wget && \
    rm -rf /var/lib/apt/lists/*
CMD ["curl", "--version"]
