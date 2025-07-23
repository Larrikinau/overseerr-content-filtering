## 🚀 Version 1.3.1: Content Filtering Stability and Performance Release

This maintenance release focuses on stability improvements, performance optimizations, and enhanced Docker deployment capabilities for Overseerr Content Filtering.

### ✨ Key Improvements & Fixes

#### 🛠️ Stability & Performance Enhancements

• Enhanced build process with improved remote compilation consistency
• Optimized database migration handling with better error recovery
• Improved Docker container startup reliability and performance
• Enhanced memory management and resource utilization

#### 🐳 Docker Deployment Improvements

• Streamlined Docker build process with reduced image overhead
• Enhanced container initialization and migration handling
• Improved multi-platform compatibility (AMD64, ARM64, ARM32/v7)
• Better Docker Hub integration and deployment automation

#### 🔧 Infrastructure & Build Improvements

• Enhanced GitHub Actions workflow for consistent builds
• Improved package generation and release automation
• Better SHA256 integrity verification for releases
• Streamlined development and deployment pipeline

#### 📊 Content Filtering Refinements

• Improved TMDB Curated Discovery performance and reliability
• Enhanced admin-only content controls with better user experience
• Optimized content rating filter application across all discovery modes
• Better error handling for edge cases in content filtering

### 🐳 Docker Images Available

• Latest: larrikinau/overseerr-content-filtering:1.3.1
• Also tagged: larrikinau/overseerr-content-filtering:latest
• Multi-platform support: AMD64, ARM64, ARM32/v7

### 📦 Installation Options

#### Docker (Recommended)
docker pull larrikinau/overseerr-content-filtering:1.3.1

#### Pre-built Package (Debian/Ubuntu)
Download: overseerr-content-filtering-v1.3.1-ubuntu.tar.gz
SHA256: 595e68916ec1db337f0b0c6468588ec29984a7a9698ef5d935295eb89c5a8a44

#### Quick Install Script
curl -fsSL https://github.com/Larrikinau/overseerr-content-filtering/raw/main/install-overseerr-filtering.sh | bash

### 🔄 Migration from Previous Versions

Existing users can migrate seamlessly using the migration script.

### 🛡️ Compatibility & Safety

• Full backward compatibility from Overseerr v1.x installations
• Automatic database migrations with rollback support
• 100% data preservation during migration
• Production tested and verified

Full Changelog: v1.3.0...v1.3.1
