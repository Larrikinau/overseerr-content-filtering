import TheMovieDb from '@server/api/themoviedb';
import type { TmdbSearchMultiResponse } from '@server/api/themoviedb/interfaces';
import Media from '@server/entity/Media';
import { User } from '@server/entity/User';
import { findSearchProvider } from '@server/lib/search';
import logger from '@server/logger';
import { mapSearchResults } from '@server/models/Search';
import { Router } from 'express';
import { createTmdbWithRegionLanguage } from './discover';

const filterResultsByRating = (results: any[], user?: User): any[] => {
  // Always apply basic adult content filtering, even if no user rating limits are set
  if (!user?.settings) {
    // If no user settings, apply basic adult content filtering only
    return results.filter((result: any) => !result.adult);
  }
  
  // If user settings exist but no rating limits are set, apply basic filtering
  if (!user.settings.maxMovieRating && !user.settings.maxTvRating) {
    return results.filter((result: any) => !result.adult);
  }

  return results.filter((result: any) => {
    if (!user?.settings) return true;

    const isMovie = result.media_type === 'movie' || (!result.media_type && result.title);
    const isTv = result.media_type === 'tv' || (!result.media_type && result.name);
    
    // Movie filtering based on user setting
    if (isMovie && user.settings.maxMovieRating) {
      const maxRating = user.settings.maxMovieRating;
      
      // Always block adult content unless no restrictions
      if (result.adult && maxRating !== '') {
        return false;
      }
      
      // Use genre-based heuristics to filter content since certification data is unreliable
      const genreIds = result.genre_ids || [];
      
      if (maxRating === 'G') {
        // Block PG and above - very restrictive
        // Block: Action, Adventure, Thriller, Horror, Crime, War, Western
        if (genreIds.some((id: number) => [28, 12, 53, 27, 80, 10752, 37].includes(id))) {
          return false;
        }
      }
      
      if (maxRating === 'PG') {
        // Block PG-13 and above - moderately restrictive
        // Block: Thriller, Horror, Crime, War
        if (genreIds.some((id: number) => [53, 27, 80, 10752].includes(id))) {
          return false;
        }
      }
      
      if (maxRating === 'PG-13') {
        // Block R and above - less restrictive
        // Block: Horror, very violent content
        if (genreIds.some((id: number) => [27].includes(id))) {
          return false;
        }
      }
    }
    
    // TV filtering based on user setting
    if (isTv && user.settings.maxTvRating) {
      const maxRating = user.settings.maxTvRating;
      
      // Use genre-based heuristics for TV shows
      const genreIds = result.genre_ids || [];
      
      if (maxRating === 'TV-Y' || maxRating === 'TV-Y7') {
        // Very restrictive - only children's content
        // Block most genres except Animation, Family
        if (genreIds.some((id: number) => ![16, 10751].includes(id)) && genreIds.length > 0) {
          return false;
        }
      }
      
      if (maxRating === 'TV-G') {
        // Block PG and above content
        // Block: Drama with serious themes, Crime, War
        if (genreIds.some((id: number) => [18, 80, 10752].includes(id))) {
          return false;
        }
      }
      
      if (maxRating === 'TV-PG') {
        // Block TV-14 and above
        // Block: Thriller, Crime, War, Adult-oriented content
        if (genreIds.some((id: number) => [53, 80, 10752].includes(id))) {
          return false;
        }
      }
      
      if (maxRating === 'TV-14') {
        // Block TV-MA content
        // Block: Very mature content indicators
        if (genreIds.some((id: number) => [27].includes(id))) { // Horror typically TV-MA
          return false;
        }
      }
    }

    return true;
  });
};

const searchRoutes = Router();

searchRoutes.get('/', async (req, res, next) => {
  const queryString = req.query.query as string;
  const searchProvider = findSearchProvider(queryString.toLowerCase());
  let results: TmdbSearchMultiResponse;

  try {
    if (searchProvider) {
      const [id] = queryString
        .toLowerCase()
        .match(searchProvider.pattern) as RegExpMatchArray;
      results = await searchProvider.search({
        id,
        language: (req.query.language as string) ?? req.locale,
        query: queryString,
      });
    } else {
      const tmdb = createTmdbWithRegionLanguage(req.user);

      results = await tmdb.searchMulti({
        query: queryString,
        page: Number(req.query.page),
        language: (req.query.language as string) ?? req.locale,
      });
    }

    // Apply content filtering based on user preferences
    const filteredResults = filterResultsByRating(results.results, req.user as User);

    const media = await Media.getRelatedMedia(
      filteredResults.map((result) => result.id)
    );

    return res.status(200).json({
      page: results.page,
      totalPages: results.total_pages,
      totalResults: filteredResults.length,
      results: mapSearchResults(filteredResults, media),
    });
  } catch (e) {
    logger.debug('Something went wrong retrieving search results', {
      label: 'API',
      errorMessage: e.message,
      query: req.query.query,
    });
    return next({
      status: 500,
      message: 'Unable to retrieve search results.',
    });
  }
});

searchRoutes.get('/keyword', async (req, res, next) => {
  const tmdb = new TheMovieDb();

  try {
    const results = await tmdb.searchKeyword({
      query: req.query.query as string,
      page: Number(req.query.page),
    });

    return res.status(200).json(results);
  } catch (e) {
    logger.debug('Something went wrong retrieving keyword search results', {
      label: 'API',
      errorMessage: e.message,
      query: req.query.query,
    });
    return next({
      status: 500,
      message: 'Unable to retrieve keyword search results.',
    });
  }
});

searchRoutes.get('/company', async (req, res, next) => {
  const tmdb = new TheMovieDb();

  try {
    const results = await tmdb.searchCompany({
      query: req.query.query as string,
      page: Number(req.query.page),
    });

    return res.status(200).json(results);
  } catch (e) {
    logger.debug('Something went wrong retrieving company search results', {
      label: 'API',
      errorMessage: e.message,
      query: req.query.query,
    });
    return next({
      status: 500,
      message: 'Unable to retrieve company search results.',
    });
  }
});

export default searchRoutes;
