import TheMovieDb from '@server/api/themoviedb';
import type { TmdbSearchMultiResponse } from '@server/api/themoviedb/interfaces';
import Media from '@server/entity/Media';
import { User } from '@server/entity/User';
import { findSearchProvider } from '@server/lib/search';
import logger from '@server/logger';
import { mapSearchResults } from '@server/models/Search';
import { Router } from 'express';
import { createTmdbWithRegionLanguage } from './discover';

/**
 * Filter search results by certification-based content ratings
 * This replaces the old genre-based heuristic filtering with proper TMDB certification lookup
 * @param results - Array of search results from TMDB
 * @param tmdb - TheMovieDb instance with user's rating preferences
 * @returns Promise of filtered results using certification data
 */
const filterResultsByRating = async (results: any[], tmdb: TheMovieDb): Promise<any[]> => {
  // Separate results by media type for proper certification filtering
  const movieResults = results.filter(
    (result) => result.media_type === 'movie' || (!result.media_type && result.title)
  );
  const tvResults = results.filter(
    (result) => result.media_type === 'tv' || (!result.media_type && result.name)
  );
  const otherResults = results.filter(
    (result) => result.media_type !== 'movie' && result.media_type !== 'tv' && result.media_type !== undefined
  );

  // Apply certification-based filtering using TheMovieDb methods
  const filteredMovies = await tmdb.filterMoviesByCertification(movieResults);
  const filteredTv = await tmdb.filterTvByRating(tvResults);

  // Combine filtered results, maintaining original order as much as possible
  return [...filteredMovies, ...filteredTv, ...otherResults];
};

const searchRoutes = Router();

searchRoutes.get('/', async (req, res, next) => {
  const queryString = req.query.query as string;
  const searchProvider = findSearchProvider(queryString.toLowerCase());
  let results: TmdbSearchMultiResponse;
  const tmdb = createTmdbWithRegionLanguage(req.user);

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
      results = await tmdb.searchMulti({
        query: queryString,
        page: Number(req.query.page),
        language: (req.query.language as string) ?? req.locale,
      });
    }

    // Apply certification-based content filtering (Issue #13 fix)
    const filteredResults = await filterResultsByRating(results.results, tmdb);

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
