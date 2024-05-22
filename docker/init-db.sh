#!/bin/bash

databases=(${DATABASES[@]:-"postgres"})

for db in "${databases[@]}"; do
    echo "Checking and creating database if not exists: $db"

    psql -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1 || psql -d postgres -c "CREATE DATABASE \"$db\";"

    EXTENSION_NAME="mumak${MUMAK_VERSION:+_$MUMAK_VERSION}"
    
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

    echo "Initialization completed for database: $db"
done
