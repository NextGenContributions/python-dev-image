#!/usr/bin/env bash
#
# This script builds and tests a Docker image for multiple platforms (amd64 and arm64).
# It uses Docker Buildx to build the image and container-structure-test to run tests on the built image.
#
# Usage: ./test.sh [platform]
#
# If no platform is specified, it defaults to "linux/amd64 linux/arm64".

set -euxo pipefail

BASE_IMAGE="python-dev-image"
TEST_IMAGE="python-dev-test-image"

platforms="${1:-linux/amd64 linux/arm64}"

# Check if container-structure-test supports --platform flag
# Linux binaries of container-structure-test may not support --platform flag
# and thus can only run tests for the local architecture.
PLATFORM_FLAG=""
if container-structure-test test --help 2>&1 | grep -q -- '--platform'; then
    PLATFORM_FLAG="--platform"
fi

# Build and test function that takes platform as parameter
build_and_test() {
    local platform=$1
    local tag=$2

    BASE_PLATFORM_IMAGE="$BASE_IMAGE-$platform:$tag"
    TEST_PLATFORM_IMAGE="$TEST_IMAGE-$platform:$tag"

    echo "Building and testing for platform: $platform with tag: $tag"

    # Build the base image
    docker build --load --platform "$platform" -t "$BASE_PLATFORM_IMAGE" -f Dockerfile .

    # Build the test image (use classic docker build for local-only workaround)
    docker build --load --platform "$platform" -t "$TEST_PLATFORM_IMAGE" --build-arg BASE_IMAGE="$BASE_PLATFORM_IMAGE" --build-arg PLATFORM="$platform" -f tests/test-data/build-context/Dockerfile tests/test-data/build-context

    docker run --platform "$platform" --rm "$TEST_PLATFORM_IMAGE" uname -m

    # Conditionally add --platform flag
    PLATFORM_ARG=()
    if [ -n "$PLATFORM_FLAG" ]; then
        PLATFORM_ARG=(--platform "$platform")
    fi

    if [ "$platform" == "linux/amd64" ]; then
        container-structure-test test "${PLATFORM_ARG[@]}" --image "$TEST_PLATFORM_IMAGE" --config tests/amd64.yaml
    else
        container-structure-test test "${PLATFORM_ARG[@]}" --image "$TEST_PLATFORM_IMAGE" --config tests/arm64.yaml
    fi

    # Run the tests
    container-structure-test test "${PLATFORM_ARG[@]}" --image "$TEST_PLATFORM_IMAGE" --config tests/specs.yaml

    # Clean up
    docker rmi $TEST_IMAGE:"$tag" || true
}

for platform in $platforms; do
    # Build and test for each platform
    build_and_test "$platform" "latest"
done
