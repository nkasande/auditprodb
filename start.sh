#!/bin/bash
set -e

for file in $(ls -1 *.sql | sort); do
  echo "Running $file..."
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -f "$file" || exit 1
done

echo "All scripts completed successfully"
