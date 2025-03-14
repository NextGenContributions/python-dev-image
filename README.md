# Python base image for development purpose

Specially created Docker image for Python to work as a devcontainer for development purposes. 

## Contains

It contains:

- `python` - Python sourced from official Python image on Docker Hub. We are using now Python version 3.12 as it is now the latest Python version supported by the type checkers we use. 
- `uv` - for Python package management

It contains the neccesary dependencies for running various linters and type checkers:

- `watchman` - for running Pyre Python type checker 
- `shfmt` - for shell script formatting
- `reviewdog` - for code review
- `hadolint` - for linting Dockerfile
- `actionlint` - static checker for GitHub Actions workflow files

## Usage

We host the image on [Github packages](https://github.com/NextGenContributions/python-dev-image/pkgs/container/python-dev-image).

You can use it the like this:

Command line:
```shell
docker pull ghcr.io/nextgencontributions/python-dev-image
```

In your project's `Dockerfile`:
```Dockerfile
FROM ghcr.io/nextgencontributions/python-dev-image

# Do your own customizations here...
```

With VSCode in `.devcontainer/devcontainer.json`:
```jsonc
// For format details, see https://aka.ms/devcontainer.json.
{
	"name": "Python 3",
	"image": "ghcr.io/nextgencontributions/python-dev-image"
}
```
