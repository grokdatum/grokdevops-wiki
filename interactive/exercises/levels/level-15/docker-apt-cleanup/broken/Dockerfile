FROM ubuntu:22.04
RUN apt-get update
RUN apt-get install -y curl wget
RUN rm -rf /var/lib/apt/lists/*
CMD ["curl", "--version"]
