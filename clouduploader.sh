#!/bin/bash

# Read GCP credentials and configuration from environment variables or use defaults
GCP_ACCOUNT="$GCP_ACCOUNT"
GCP_PROJECT="$GCP_PROJECT"
GCS_BUCKET="$GCS_BUCKET"
SERV_ACC="$SERV_ACC"

# Check for required options
if [ -z "$GCP_ACCOUNT" ] || [ -z "$GCP_PROJECT" ] || [ -z "$GCS_BUCKET" ]; then
  echo "GCP credentials and configuration not set. Please configure the script with your GCP details."
  exit 1
fi

# Authenticate with GCP account
gcloud auth activate-service-account --key-file "$SERV_ACC"

# Set the default project
gcloud config set project "$GCP_PROJECT"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -f)
      shift
      FILES+=("$@")
      break
      ;;
    *)
      echo "Unknown option: $key"
      exit 1
      ;;
  esac
done

# Check for required options
if [ ${#FILES[@]} -eq 0 ]; then
  echo "Usage: $0 -f <file_path1> [file_path2 file_path3 ...]"
  exit 1
fi

# Iterate over each file and upload to GCS
for FILE_PATH in "${FILES[@]}"; do

# Extract file name from path
FILE_NAME=$(basename "$FILE_PATH")

# Check if the file already exists in GCS
if gsutil ls "gs://$GCS_BUCKET/$FILE_NAME" 2>/dev/null; then
  # File exists, prompt user for action
  read -p "File '$FILE_NAME' already exists in GCS. Do you want to (O)verwrite, (S)kip, or (R)ename the file? [O/S/R]: " CHOICE    
    
    case $CHOICE in
    [Oo])
      # Overwrite the existing file
      pv "$FILE_PATH" | gsutil cp - "gs://$GCS_BUCKET/$FILE_NAME"
      ;;
    [Ss])
      # Skip the upload
      echo "Skipped uploading '$FILE_NAME' to GCS."
      ;;
    [Rr])
      # Rename the file and upload
      NEW_NAME="${FILE_NAME}_$(date +%Y%m%d%H%M%S)"
      pv "$FILE_PATH" | gsutil cp - "gs://$GCS_BUCKET/$NEW_NAME"
      echo "File renamed to '$NEW_NAME' and uploaded to GCS bucket."
      ;;
    *)
      # Invalid choice
      echo "Invalid choice. Exiting without uploading."
      exit 1
      ;;
  esac
else

  # File doesn't exist, upload it
  pv "$FILE_PATH" | gsutil cp - "gs://$GCS_BUCKET/$FILE_NAME"
fi

# Check the exit status of the upload command
if [ $? -eq 0 ]; then
  echo "File '$FILE_NAME' successfully uploaded to GCS bucket."
    
# Provide an option to generate and display a shareable link
    read -p "Do you want to generate and display a shareable link for '$FILE_NAME'? (Y/N): " LINK_CHOICE

    case $LINK_CHOICE in
      [Yy])
        # Generate and display a shareable link
        GCS_LINK=$(gsutil signurl -d 1h key.json "gs://$GCS_BUCKET/$FILE_NAME")
        echo "Shareable link for '$FILE_NAME': $GCS_LINK"
        ;;
      [Nn])
        # Continue without generating a link
        ;;
      *)
        echo "Invalid choice. Continuing without generating a link."
        ;;
    esac
   else
    echo "Error uploading file '$FILE_NAME' to GCS. Check your configuration and try again."
  fi
done
