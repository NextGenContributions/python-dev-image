# syntax=docker/dockerfile:1

# Version of actionlint to install: latest, or specific version number WITHOUT 'v' prefix e.g. 1.7.5
ARG ACTIONLINT_VERSION=latest
# Version of taplo to install: latest, or specific version number WITHOUT 'v' prefix e.g. 0.10.0
ARG TAPLO_VERSION=latest
# Version of hadolint to install: latest, or specific version number e.g. v2.14.0
ARG HADOLINT_VERSION=latest
# Version of shellcheck to install: latest, or specific version number e.g. v0.11.0
ARG SHELLCHECK_VERSION=latest
# Version of shfmt to install: latest, or specific version number e.g. v3.12.0
ARG SHFMT_VERSION=latest
# Version of uv to install: latest, or specific version number e.g. v0.9.17
ARG UV_VERSION=latest
# Version of reviewdog to install: latest, or specific version number e.g. v0.21.0
ARG REVIEWDOG_VERSION=latest
# Version of Snyk to install: stable, latest, or specific version number e.g. v1.1301.1
ARG SNYK_VERSION=stable

# Images which we can directly copy the binaries from
FROM rhysd/actionlint:${ACTIONLINT_VERSION} AS actionlint
FROM tamasfe/taplo:${TAPLO_VERSION} AS taplo
FROM hadolint/hadolint:${HADOLINT_VERSION} AS hadolint
FROM koalaman/shellcheck:${SHELLCHECK_VERSION} AS shellcheck
FROM mvdan/shfmt:${SHFMT_VERSION} AS shfmt



# Using debian as base since it's generally stable, compatible and well supported
FROM debian:13 AS base

# Docker built-in arg for multi-platform builds
ARG TARGETARCH

# Redeclare args for use in this scope
ARG UV_VERSION
ARG REVIEWDOG_VERSION
ARG SNYK_VERSION

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV JAVA_HOME=/usr/lib/jvm/java-openjdk
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install and configure locales
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends locales \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Deprioritize 'testing' to prevent accidental installs from it.
# Packages from testing will still be available when explicitly requested with '-t testing'.
COPY <<-EOT /etc/apt/preferences.d/99pin-testing
Package: *
Pin: release a=testing
Pin-Priority: 100
EOT

# Temporarily enable 'testing' repo for outdated/unavailable packages in 'stable' repo,
# especially those that are difficult to build/install elsewhere
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    echo "deb http://deb.debian.org/debian testing main" > /etc/apt/sources.list.d/testing.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests -t testing \
    # Required for pyre vscode extension
    watchman \
    # Disable 'testing' repo afterwards to prevents potential issues
    # where only stable packages are expected (e.g. playwright install-deps)
    && rm -f /etc/apt/sources.list.d/testing.list

# https://docs.docker.com/build/cache/optimize/#use-cache-mounts
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
    # Required for sonarqube vscode extension
    openjdk-21-jre-headless \
    nodejs \
    # Required for general purpose compilation and build tools:
    gcc \
    pkg-config \
    ### General purpose tools
    curl \
    wget \
    git \
    openssh-client \
    jq \
    zsh \
    # Database clients:
    postgresql-client \
    libmariadb-dev \
    libmariadb-dev-compat \
    # For ODBC support:
    unixodbc-dev \
    freetds-dev \
    tdsodbc \
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
    # Pager for git, diff, grep, and blame
    git-delta \
    # Fuzzy finder
    fzf \
    # Code counter
    tokei \
    # Benchmarking tool
    hyperfine

# Linking preferred alternatives
RUN ln -s /usr/bin/eza /usr/local/bin/ls \
    && ln -s /usr/bin/batcat /usr/local/bin/bat \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    # Make sure java runtime is found for sonarqube
    && ln -s "$(dirname "$(dirname "$(readlink -f "$(which java)")")")" "${JAVA_HOME}"

# Install uv
RUN UV_VER="${UV_VERSION#v}" \
    && UV_INSTALL_URL=$([ "${UV_VER}" = "latest" ] \
    && echo "https://astral.sh/uv/install.sh" || \
    echo "https://astral.sh/uv/${UV_VER}/install.sh") \
    && curl -LsSf "${UV_INSTALL_URL}" | env UV_INSTALL_DIR="/usr/local/bin" sh

# Install reviewdog
RUN curl -sfL "https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh" \
    | sh -s -- -b /usr/local/bin \
    "$([ "${REVIEWDOG_VERSION}" != "latest" ] && echo "${REVIEWDOG_VERSION}" || echo "")"

# Install snyk
RUN RELEASE_JSON=$(curl -s "https://downloads.snyk.io/cli/${SNYK_VERSION}/release.json") \
    && BINARY_NAME="snyk-linux$([ "${TARGETARCH}" = "arm64" ] && echo "-arm64" || echo "")" \
    && SNYK_URL=$(echo "${RELEASE_JSON}" | jq -r ".assets.\"${BINARY_NAME}\".url") \
    && SNYK_SHA256=$(echo "${RELEASE_JSON}" | jq -r ".assets.\"${BINARY_NAME}\".sha256" | awk '{print $1}') \
    && curl -o /usr/local/bin/snyk -L "${SNYK_URL}" \
    && echo "${SNYK_SHA256}  /usr/local/bin/snyk" | sha256sum -c - \
    && chmod +x /usr/local/bin/snyk

# Install hadolint
COPY --from=hadolint /bin/hadolint /usr/local/bin/hadolint

# Install actionlint
COPY --from=actionlint /usr/local/bin/actionlint /usr/local/bin/actionlint

# Install taplo (TOML formatter and linter)
COPY --from=taplo /taplo /usr/local/bin/taplo

# Install shellcheck
# Required for shellcheck vscode extension and actionlint
COPY --from=shellcheck /bin/shellcheck /usr/local/bin/shellcheck

# Install shfmt (Shell formatter)
COPY --from=shfmt /bin/shfmt /usr/local/bin/shfmt

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
