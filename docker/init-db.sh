#!/bin/bash

# Check if MUMAK_VERSION environment variable is set
if [ -z "$MUMAK_VERSION" ]; then
  EXTENSION_NAME="mumak"
else
  EXTENSION_NAME="mumak_$MUMAK_VERSION"
fi

# Create the extension
psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS $EXTENSION_NAME;"

# Create the blocks table
psql -d postgres -c "
CREATE TABLE IF NOT EXISTS blocks (
    slot INTEGER NOT NULL,
    cbor BYTEA
);"

# Create the index for the blocks table
psql -d postgres -c "CREATE INDEX IF NOT EXISTS idx_blocks_slot ON blocks(slot);"

# Create the txs table
psql -d postgres -c "
CREATE TABLE IF NOT EXISTS txs (
    slot INTEGER NOT NULL,
    cbor BYTEA
);"

# Create the index for the txs table
psql -d postgres -c "CREATE INDEX IF NOT EXISTS idx_txs_slot ON txs(slot);"
