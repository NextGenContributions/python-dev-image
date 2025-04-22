# Python base image for development purpose

Specially created Docker image for Python to work as a devcontainer for development purposes.

NOTE: This image is NOT meant to be used as a production image.

## Contains

It contains:

- `uv` - for Python package management
- `python` - Python version that is defined in `.python-version` file in the child image.

It contains the necessary dependencies for running various linters and type checkers:

- `watchman` - for running Pyre Python type checker
- `shfmt` - for shell script formatting
- `shellcheck` - for shell script linting
- `reviewdog` - for code review
- `hadolint` - for linting Dockerfile
- `actionlint` - static checker for GitHub Actions workflow files

Other tools:

- `pulumi` - Pulumi CLI for infrastructure as code

## Usage

We host the image on [Github packages](https://github.com/NextGenContributions/python-dev-image/pkgs/container/python-dev-image).

You can use it the like this:

### As a standalone image

Command line:

```shell
docker run --rm ghcr.io/nextgencontributions/python-dev-image
```

### As a base image

In your project's `Dockerfile`:

```Dockerfile
FROM ghcr.io/nextgencontributions/python-dev-image # AS scratch

# Do your own customizations here...
```

NOTE: When using this as a base image, you should have the following files available in your build context:

- `pyproject.toml`
- `uv.lock`
- `.python-version` - this will be used to install the Python version in the container.

If you don't have these files, you can create them by running the following commands:

```shell
uv init
uv lock
uv python pin 3.12 # or replace with any other Python version you want
```

Or in a single command in your project's root directory:

```shell
docker run --rm -v $(pwd):/app ghcr.io/nextgencontributions/python-dev-image \
    sh -c "cd /app && uv init && uv lock && uv python pin 3.12"
```

### As a devcontainer

With VSCode in `.devcontainer/devcontainer.json`:

```jsonc
// For format details, see https://aka.ms/devcontainer.json.
{
    "name": "Python 3",
    "image": "ghcr.io/nextgencontributions/python-dev-image"
    // Do your own customizations here...
}
```
