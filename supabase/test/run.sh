#!/usr/bin/env bash
# Teste supabase/schema.sql sur un PostgreSQL vierge (CI : service postgres:16).
# Usage : PGHOST=… PGUSER=… PGPASSWORD=… supabase/test/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
export PGOPTIONS='-c client_min_messages=warning'
q() { psql -v ON_ERROR_STOP=1 -q "$@"; }
q -d postgres -c 'drop database if exists collectear_test' -c 'create database collectear_test'
q -d collectear_test -f supabase/test/mock_supabase.sql
# Deux passages : le script doit être ré-exécutable sans erreur.
q -d collectear_test -f supabase/schema.sql
q -d collectear_test -f supabase/schema.sql
PGOPTIONS='-c client_min_messages=notice' q -d collectear_test -f supabase/test/checks.sql
