# Overseerr Content Filtering v1.3.2 Release Notes

## Release Date: 
2025-07-20

## Overview

Version 1.3.2 focuses on resolving TMDB API integration issues across the installation scripts and updates all relevant documentation to reference the correct version number.

## Changes

- TMDB API key handling fixed in all installation scripts.
- All documentation updated to reference version 1.3.2.
- Updated Docker and migration scripts to pull and tag the latest image correctly.

## Important Notes

- Version 1.3.2 ensures that all setup methods consistently integrate the TMDB API, preventing service disruptions related to missing API keys.

## Upgrade Instructions

1. If running via Docker, pull the latest image:
   ```bash
   docker pull larrikinau/overseerr-content-filtering:1.3.2
   ```
2. Restart the container to apply the updated image.
3. For manual or scripted installations, follow the updated installation guide in the documentation.

Visit our [GitHub repository](https://github.com/Larrikinau/overseerr-content-filtering) for more details.
