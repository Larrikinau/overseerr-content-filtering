#!/bin/bash

# Backup existing docker-compose
cp docker-compose.yml docker-compose.yml.backup

# Check if environment variables are already defined in the docker-compose.yml
if ! grep -q 'TMDB_API_KEY' docker-compose.yml; then
    cat <<EOL >>docker-compose.yml
  # API Keys
    environment:
      - TMDB_API_KEY=my-tmdb-api-key
      - ALGOLIA_API_KEY=my-algolia-api-key
EOL
fi

# Ensure the test environment matches production environment configurations
sed -i '' 's/MY_TMDB_API_KEY_HERE/db55323b8d3e4154498498a75642b381/' docker-compose.yml
sed -i '' 's/MY_ALGOLIA_API_KEY_HERE/175588f6e5f8319b27702e4cc4013561/' docker-compose.yml

# Notify user
echo "Test environment docker-compose.yml has been updated to use environment variables for API keys."
