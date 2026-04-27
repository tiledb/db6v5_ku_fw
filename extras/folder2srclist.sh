#!/bin/bash

# Usage: ./update_list.sh path/to/folder path/to/others.src

TARGET_DIR=$1
SRC_FILE=$2

if [ -z "$TARGET_DIR" ] || [ -z "$SRC_FILE" ]; then
    echo "Usage: $0 <folder_path> <src_file_path>"
    exit 1
fi

# Use find to get all files, strip leading './', and append to src file
# You can filter by extension by adding: -name "*.vhd" -o -name "*.v"
find "$TARGET_DIR" -type f ! -name ".*" >> "$SRC_FILE"

echo "Files from $TARGET_DIR added to $SRC_FILE"
