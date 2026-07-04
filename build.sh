#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
machin encode src/crm.src > build/crm.mfl
machin build build/crm.mfl -o crm
echo "built ./crm"
