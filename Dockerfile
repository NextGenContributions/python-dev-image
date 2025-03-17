FROM python:3.12-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV JAVA_HOME=/usr/lib/jvm/java-openjdk

# https://docs.docker.com/build/cache/optimize/#use-cache-mounts
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    --mount=type=cache,target=/root/.cache/pip \
    apt-get update \
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
        jq \
        zsh \
    && pip install --no-cache-dir -U pip setuptools wheel \
    && pip install --no-cache-dir uv \
    # Install reviewdog:
    && curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh \
        | sh -s -- -b /usr/local/bin \
    # Make sure java runtime is found for sonarqube:
    && ln -s "$(dirname "$(dirname "$(readlink -f "$(which java)")")")" "$JAVA_HOME" \
    # Install other tools:
    && export ACTIONLINT_VERSION=$(curl -s https://api.github.com/repos/rhysd/actionlint/releases/latest | jq -r '.tag_name' | sed "s/v//") \
    && export HADOLINT_VERSION=$(curl -s https://api.github.com/repos/hadolint/hadolint/releases/latest | jq -r '.tag_name') \
    && if [ "$(uname -m)" = "aarch64" ]; then \
        curl -o /usr/local/bin/snyk -L https://static.snyk.io/cli/latest/snyk-linux-arm64 \
        && curl -o /usr/local/bin/hadolint -L https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-arm64 \
        && curl -o /usr/local/bin/shfmt https://github.com/patrickvane/shfmt/releases/download/master/shfmt_linux_arm \
        && curl -sL https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_arm64.tar.gz | tar -xzf - -C /usr/local/bin actionlint; \
    else \
        curl -o /usr/local/bin/snyk -L https://static.snyk.io/cli/latest/snyk-linux \
        && curl -o /usr/local/bin/hadolint -L https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64 \
        && curl -o /usr/local/bin/shfmt https://github.com/patrickvane/shfmt/releases/download/master/shfmt_linux_amd64 \
        && curl -sL https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz | tar -xzf - -C /usr/local/bin actionlint; \
    fi \
    && chmod +x /usr/local/bin/snyk \
    && chmod +x /usr/local/bin/hadolint \
    && chmod +x /usr/local/bin/shfmt \
    && chmod +x /usr/local/bin/actionlint


# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy
ENV UV_SYSTEM_PYTHON=true
ENV UV_BREAK_SYSTEM_PACKAGES=true
ENV UV_PROJECT_ENVIRONMENT=/usr/local


# Install the project's dependencies using the lockfile and settings
ONBUILD RUN --mount=type=cache,target=/root/.cache/uv \
            --mount=type=bind,source=uv.lock,target=uv.lock \
            --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
            uv sync --frozen --no-install-project
