#!/usr/bin/env bash
#
# This script builds and tests a Docker image for multiple platforms (amd64 and arm64).
# It uses Docker Buildx to build the image and container-structure-test to run tests on the built image.
#
# Usage: ./test.sh [platform]
#
# If no platform is specified, it defaults to "linux/amd64 linux/arm64".

set -euxo pipefail

TEST_IMAGE_NAME="python-dev-test-image"

platforms="${1:-linux/amd64 linux/arm64}"

# Build and test function that takes platform as parameter
build_and_test() {
    local platform=$1
    local tag=$2

    echo "Building and testing for platform: $platform with tag: $tag"

    # Build the base image
    docker buildx build --load --platform "$platform" -t python-dev-image:"$tag" -f Dockerfile .

    # Build the test image (use classic docker build for local-only workaround)
    docker build --platform "$platform" -t $TEST_IMAGE_NAME:"$tag" --build-arg BASE_IMAGE=python-dev-image:"$tag" -f tests/test-data/build-context/Dockerfile tests/test-data/build-context

    docker run --platform "$platform" --rm $TEST_IMAGE_NAME:"$tag" uname -m

    # Run the tests
    container-structure-test test --platform "$platform" --image $TEST_IMAGE_NAME:"$tag" --config tests/specs.yaml

    # Clean up
    docker rmi $TEST_IMAGE_NAME:"$tag" || true
}

for platform in $platforms; do
    # Build and test for each platform
    build_and_test "$platform" "latest"
done
