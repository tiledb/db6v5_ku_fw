#!/bin/bash

# # Define source and destination
# SOURCE="/mnt/data-nvme-01/Documents/PostDoc/TileCal/db7/db6v5_ku_fw/bin"
# DESTINATION="/mnt/PiroUbuntu2404CT/resources/db6v5_ku_fw"

# # Create the destination directory if it doesn't exist
# mkdir -p "$DESTINATION"

# # Perform the sync
# # -a: archive mode (preserves permissions, symlinks, etc.)
# # -v: verbose (shows progress)
# # -z: compress data during transfer
# # --delete: delete files in DEST that no longer exist in SOURCE
# rsync -avz --delete "$SOURCE" "$DESTINATION"

# echo "Sync complete!"


# Define pairs using the format "SOURCE|DESTINATION"
SYNC_LIST=(
    "/mnt/data-nvme-01/Documents/PostDoc/TileCal/db7/db6v5_ku_fw/bin|/mnt/PiroUbuntu2404CT/resources/db6v5_ku_fw"
    "/mnt/data-nvme-01/Documents/PostDoc/TileCal/db7/db6v5_ku_fw/Projects/db6v5_vivado_2022_2/db6v5_vivado_2022_2.runs|/mnt/PiroUbuntu2404CT/resources/db6v5_ku_fw"
)

for entry in "${SYNC_LIST[@]}"; do
    # Separate source and destination using the pipe character
    SRC="${entry%%|*}"
    DEST="${entry##*|}"

    echo "Checking $DEST..."

    # Create destination if it doesn't exist
    if [ ! -d "$DEST" ]; then
        mkdir -p "$DEST"
        echo "Created directory: $DEST"
    fi

    echo "Syncing $SRC to $DEST..."
    
    # Perform the sync
    rsync -avz "$SRC" "$DEST"

    echo "Done with $DEST"
    echo "--------------------------"
done