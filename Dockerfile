# syntax=docker/dockerfile:1
FROM ubuntu:25.10 AS base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV JAVA_HOME=/usr/lib/jvm/java-openjdk

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# https://docs.docker.com/build/cache/optimize/#use-cache-mounts
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends --no-install-suggests \
    # Required for pyre vscode extension
    watchman \
    # Required for sonarqube vscode extension
    openjdk-17-jre-headless \
    nodejs \
    # Required for shellcheck vscode extension
    shellcheck \
    # Required for general purpose compilation
    gcc \
    # General purpose tools
    curl \
    git \
    openssh-client \
    jq \
    zsh \
    postgresql-client \
    # Better alternative to grep
    ripgrep \
    # Better alternative to find
    fd-find \
    # Better alternative to top/htop
    btop \
    # Better alternative to ls
    eza \
    # Better alternative to du
    du-dust \
    # Better alternative to cat
    bat \
    # Pager for bat
    less \
    # Fuzzy finder
    fzf \
    # Code counter
    tokei \
    # Benchmarking tool
    hyperfine \
    # Linking preferred alternatives
    && ln -s /usr/bin/eza /usr/local/bin/ls \
    && ln -s /usr/bin/batcat /usr/local/bin/bat \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    # Install uv:
    && curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh \
    # Install Pulumi:
    && curl -fsSL https://get.pulumi.com | sh \
    && mv /root/.pulumi/bin/pulumi /usr/local/bin \
    # Install reviewdog:
    && curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh \
    | sh -s -- -b /usr/local/bin \
    # Make sure java runtime is found for sonarqube:
    && ln -s "$(dirname "$(dirname "$(readlink -f "$(which java)")")")" "$JAVA_HOME" \
    # Install other tools:
    && export ACTIONLINT_VERSION=$(curl -s https://api.github.com/repos/rhysd/actionlint/releases/latest | jq -r '.tag_name' | sed "s/v//") \
    && export HADOLINT_VERSION=$(curl -s https://api.github.com/repos/hadolint/hadolint/releases/latest | jq -r '.tag_name') \
    && export SHFMT_VERSION=$(curl -s https://api.github.com/repos/mvdan/sh/releases/latest | jq -r '.tag_name') \
    && if [ "$(uname -m)" = "aarch64" ]; then \
    curl -o /usr/local/bin/snyk -L https://static.snyk.io/cli/latest/snyk-linux-arm64 \
    && curl -o /usr/local/bin/hadolint -L https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-arm64 \
    && curl -o /usr/local/bin/shfmt -L https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_arm64 \
    && curl -sL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_arm64.tar.gz" | tar -xzf - -C /usr/local/bin actionlint ; \
    else \
    curl -o /usr/local/bin/snyk -L https://static.snyk.io/cli/latest/snyk-linux \
    && curl -o /usr/local/bin/hadolint -L https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64 \
    && curl -o /usr/local/bin/shfmt -L https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_amd64 \
    && curl -sL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz" | tar -xzf - -C /usr/local/bin actionlint ; \
    fi \
    && chmod +x /usr/local/bin/snyk \
    && chmod +x /usr/local/bin/hadolint \
    && chmod +x /usr/local/bin/shfmt \
    && chmod +x /usr/local/bin/actionlint

WORKDIR /app

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_INSTALL_DIR=/opt/pythons
ENV UV_PROJECT_ENVIRONMENT=/opt/venv
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

ONBUILD COPY pyproject.toml* uv.lock* .python-version* /app/

# Install the project's dependencies using the lockfile and settings
ONBUILD RUN --mount=type=ssh \
    mkdir -p ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts \
    && uv venv \
    && if [ -f "pyproject.toml" ] && [ -f "uv.lock" ]; then \
        uv sync --frozen --no-install-project --no-cache; \
    fi \
    && rm -rf /app/.python-version* /app/pyproject.toml* /app/uv.lock*
