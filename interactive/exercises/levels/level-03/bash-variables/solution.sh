#!/bin/bash
# This script processes a filename that contains spaces

FILENAME="my important file.txt"

# Create the test file
echo "test data" > "/tmp/$FILENAME"

# Fixed: Added quotes around variable to prevent word splitting
if [ -f "/tmp/$FILENAME" ]; then
    echo "SUCCESS: File found"
    cat "/tmp/$FILENAME"
else
    echo "FAIL: File not found"
fi

rm -f "/tmp/$FILENAME"
