#!/bin/bash

databases=(${DATABASES[@]:-"postgres"})
EXTENSION_NAME="mumak${MUMAK_VERSION:+_$MUMAK_VERSION}"

for db in "${databases[@]}"; do
    echo "Checking and creating database if not exists: $db"

    psql -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1 || psql -d postgres -c "CREATE DATABASE \"$db\";"
    
    psql -d "$db" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
    psql -d "$db" -c "CREATE EXTENSION IF NOT EXISTS \"$EXTENSION_NAME\";"

    psql -d "$db" -c "
    CREATE TABLE IF NOT EXISTS blocks (
        slot INTEGER NOT NULL,
        cbor BYTEA
    );"

    psql -d "$db" -c "CREATE INDEX IF NOT EXISTS idx_blocks_slot ON blocks(slot);"

    psql -d "$db" -c "
    CREATE TABLE IF NOT EXISTS txs (
        slot INTEGER NOT NULL,
        cbor BYTEA
    );"

    psql -d "$db" -c "CREATE INDEX IF NOT EXISTS idx_txs_slot ON txs(slot);"

    psql -d "$db" -c "
    CREATE TABLE utxos (
        slot INTEGER NOT NULL,
        era INTEGER NOT NULL,
        id VARCHAR PRIMARY KEY,
        spent_slot INTEGER,
        cbor BYTEA NOT NULL
    );"

    echo "Initialization completed for database: $db"
done
