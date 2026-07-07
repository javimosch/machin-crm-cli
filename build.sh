#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
machin encode framework/machweb.src framework/smtp.src src/core.src src/crm.src > build/crm.mfl
machin build build/crm.mfl -o crm
echo "built ./crm"
