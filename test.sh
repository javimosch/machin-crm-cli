#!/usr/bin/env bash
# All crm-cli tests: pure-core unit tests (machin test) + DB-backed integration tests.
set -e
cd "$(dirname "$0")"
echo "── unit (src/core.src) ──"
machin test src/core.src test/core_test.src
echo "── integration (command business rules) ──"
[ -x ./crm ] || ./build.sh
bash test/integration.sh
