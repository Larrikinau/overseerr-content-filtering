#!/usr/bin/env node

/**
 * Overseerr TMDB API Connectivity Test
 * 
 * This script tests if the TMDB API is properly configured and accessible.
 * Run this script in your Overseerr installation directory to diagnose
 * issues with missing region/language settings.
 */

const axios = require('axios');

async function testTmdbApi() {
  console.log('🔍 Testing TMDB API Configuration...\n');

  // Check environment variable
  const tmdbApiKey = process.env.TMDB_API_KEY;
  
  if (!tmdbApiKey) {
    console.log('❌ TMDB_API_KEY environment variable is not set');
    console.log('   Please set TMDB_API_KEY in your environment or .env file');
    return false;
  }

  if (tmdbApiKey === 'YOUR_TMDB_API_KEY_HERE') {
    console.log('❌ TMDB_API_KEY is set to the default placeholder value');
    console.log('   Please replace with your actual TMDB API key');
    return false;
  }

  console.log('✅ TMDB_API_KEY environment variable is set');
  console.log(`   Key: ${tmdbApiKey.substring(0, 8)}...${tmdbApiKey.substring(tmdbApiKey.length - 4)}\n`);

  try {
    // Test basic TMDB API connectivity
    console.log('🌐 Testing TMDB API connectivity...');
    const configResponse = await axios.get('https://api.themoviedb.org/3/configuration', {
      params: { api_key: tmdbApiKey }
    });
    console.log('✅ TMDB API connection successful');
    
    // Test regions endpoint
    console.log('🌍 Testing regions endpoint...');
    const regionsResponse = await axios.get('https://api.themoviedb.org/3/configuration/countries', {
      params: { api_key: tmdbApiKey }
    });
    console.log(`✅ Regions endpoint successful - Found ${regionsResponse.data.length} regions`);
    
    // Test languages endpoint  
    console.log('🗣️  Testing languages endpoint...');
    const languagesResponse = await axios.get('https://api.themoviedb.org/3/configuration/languages', {
      params: { api_key: tmdbApiKey }
    });
    console.log(`✅ Languages endpoint successful - Found ${languagesResponse.data.length} languages`);
    
    console.log('\n🎉 All TMDB API tests passed!');
    console.log('\nIf you\'re still experiencing issues with region/language settings:');
    console.log('1. Restart your Overseerr service');
    console.log('2. Clear your browser cache');
    console.log('3. Check your browser console for JavaScript errors');
    console.log('4. Try accessing /api/v1/regions and /api/v1/languages directly in your browser');
    
    return true;
    
  } catch (error) {
    console.log('❌ TMDB API test failed:');
    if (error.response) {
      console.log(`   Status: ${error.response.status}`);
      console.log(`   Message: ${error.response.data?.status_message || error.response.statusText}`);
      
      if (error.response.status === 401) {
        console.log('\n💡 This looks like an API key issue:');
        console.log('   - Verify your TMDB API key is correct');
        console.log('   - Check if your API key has been revoked');
        console.log('   - Try generating a new API key at https://www.themoviedb.org/settings/api');
      }
    } else {
      console.log(`   Error: ${error.message}`);
    }
    
    return false;
  }
}

async function testOverseerrEndpoints() {
  console.log('\n🔧 Testing Overseerr internal endpoints...');
  
  // These would need to be run from within the Overseerr application context
  console.log('ℹ️  To test Overseerr\'s /api/v1/regions and /api/v1/languages endpoints:');
  console.log('   1. Open your browser and go to your Overseerr URL');
  console.log('   2. Login and open Developer Tools (F12)');
  console.log('   3. Go to Network tab and navigate to Settings > General');
  console.log('   4. Look for requests to /api/v1/regions and /api/v1/languages');
  console.log('   5. If they return errors, the issue is with Overseerr\'s TMDB integration');
}

// Run the tests
if (require.main === module) {
  testTmdbApi().then((success) => {
    if (success) {
      testOverseerrEndpoints();
    }
    process.exit(success ? 0 : 1);
  });
}

module.exports = { testTmdbApi };
