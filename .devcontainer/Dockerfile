FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# required tool for alr and gnat
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl \
    unzip \
    git \
    make \
    build-essential \
    gnat \
    gprbuild \
    bubblewrap \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install Alire (alr)
ARG ALIRE_VERSION=1.2.2
RUN curl -L https://github.com/alire-project/alire/releases/download/v${ALIRE_VERSION}/alr-${ALIRE_VERSION}-bin-x86_64-linux.zip -o alr.zip \
    && unzip alr.zip -d /tmp/alire_extracted \
    && mv /tmp/alire_extracted/bin/alr /usr/local/bin/alr \
    && rm -rf alr.zip /tmp/alire_extracted

# for vs code config
ENV PATH="/usr/local/bin:${PATH}"