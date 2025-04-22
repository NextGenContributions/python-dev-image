#!/usr/bin/env bash
#
# This script builds and tests a Docker image for multiple platforms (amd64 and arm64).
# It uses Docker Buildx to build the image and container-structure-test to run tests on the built image.
#
# Usage: ./test.sh

set -euxo pipefail

TEST_IMAGE_NAME="python-dev-test-image"

# Build and test function that takes platform as parameter
build_and_test() {
    local platform=$1
    local tag=$2

    echo "Building and testing for platform: $platform with tag: $tag"

    # Build the base image
    docker buildx build --platform "$platform" -t python-dev-image:"$tag" -f Dockerfile .

    # Build the test image
    docker buildx build --platform "$platform" -t $TEST_IMAGE_NAME:"$tag" -f tests/test-data/build-context/Dockerfile tests/test-data/build-context

    docker run --platform "$platform" --rm $TEST_IMAGE_NAME:"$tag" uname -m

    # Run the tests
    container-structure-test test --platform "$platform" --image $TEST_IMAGE_NAME:"$tag" --config tests/specs.yaml

    # Clean up
    docker rmi $TEST_IMAGE_NAME:"$tag" || true
}

# Run for amd64
build_and_test "linux/amd64" "latest"

# Run for arm64
build_and_test "linux/arm64" "latest"
