#!/usr/bin/env bash
# Unit tests for the pure core (src/core.src). Runs framework/test.src's assert* helpers.
set -e
cd "$(dirname "$0")"
machin test src/core.src test/core_test.src
