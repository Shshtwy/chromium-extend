FROM --platform=linux/amd64 ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        file \
        git \
        lsb-release \
        locales \
        pkg-config \
        python3 \
        python3-pip \
        rsync \
        sudo \
        unzip \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 \
    && useradd --create-home --uid 1000 --shell /bin/bash builder \
    && echo "builder ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/builder \
    && chmod 0440 /etc/sudoers.d/builder

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PATH=/home/builder/depot_tools:${PATH}

USER builder
WORKDIR /work

CMD ["/bin/bash"]
