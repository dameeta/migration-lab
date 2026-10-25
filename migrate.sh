#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR="sales_source"
BUCKET_NAME="migration-automate-backup-bucket"
DEST_PREFIX="sales"

if [[ ! -d "$SOURCE_DIR" ]]; then
echo "ERROR: Source directory does not exist."
exit 1
fi

if ! find "$SOURCE_DIR" -type f -print -quit | grep -q .; then
echo "ERROR: Source directory contains no files."
exit 1
fi

echo "Step 1: Uploading source files..."
aws s3 sync "$SOURCE_DIR/" \
"s3://$BUCKET_NAME/$DEST_PREFIX/"

echo "Step 2: Checking source and destination file counts..."
SOURCE_COUNT=$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')
DEST_COUNT=$(aws s3api list-objects-v2 \
--bucket "$BUCKET_NAME" \
--prefix "$DEST_PREFIX/" \
--query 'length(Contents || `[]`)' \
--output text)

if [[ "$SOURCE_COUNT" != "$DEST_COUNT" ]]; then
echo "ERROR: File count mismatch."
echo "Source: $SOURCE_COUNT; Destination: $DEST_COUNT"
exit 1
fi

echo "Step 3: Verifying file checksums..."
while IFS= read -r -d '' FILE; do
RELATIVE_PATH="${FILE#"$SOURCE_DIR"/}"
aws s3 cp "s3://$BUCKET_NAME/$DEST_PREFIX/$RELATIVE_PATH" - |
cmp - "$FILE"
done < <(find "$SOURCE_DIR" -type f -print0)

echo "SUCCESS: Migration validation completed."
