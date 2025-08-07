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
  // Define explicit adult content keywords that should always be blocked unless user allows XXX
  const adultKeywords = [
    'porn', 'porno', 'xxx', 'sex', 'adult', 'erotic', 'nude', 'naked', 'sexy',
    'milf', 'lesbian', 'gay', 'bisexual', 'orgasm', 'masturbat', 'dildo',
    'fetish', 'bdsm', 'kinky', 'horny', 'cumshot', 'blowjob', 'anal',
    'threesome', 'gangbang', 'stripper', 'prostitut', 'hooker', 'escort',
    'playboy', 'penthouse', 'hustler', 'vivid', 'wicked', 'bangbros'
  ];

  const isAdultContent = (title: string): boolean => {
    const lowerTitle = title.toLowerCase();
    // Be more specific - avoid false positives with names
    return adultKeywords.some(keyword => {
      // For "porn", make sure it's a standalone word or part of "porno"
      if (keyword === 'porn') {
        return lowerTitle.includes('porn ') || lowerTitle.includes(' porn') || 
               lowerTitle.startsWith('porn') || lowerTitle.endsWith('porn') ||
               lowerTitle.includes('porno');
      }
      return lowerTitle.includes(keyword);
    });
  };

  console.log('=== FILTER DEBUG ===');
  console.log('User settings:', user?.settings);
  console.log('Total results before filtering:', results.length);
  
  const filtered = results.filter((result: any) => {
    if (!user?.settings) return true;

    const isMovie = result.media_type === 'movie' || (!result.media_type && result.title);
    const isTv = result.media_type === 'tv' || (!result.media_type && result.name);
    const title = result.title || result.name || '';
    
    // Check if content appears to be adult based on title/keywords
    const seemsAdult = isAdultContent(title);
    
    // Always filter adult content - block XXX content based on user setting
    if (result.adult || seemsAdult) {
      console.log(`Adult content detected: "${title}", TMDB adult flag: ${result.adult}, keyword match: ${seemsAdult}`);
      
      // For movies: if maxMovieRating is 'Adult', it means "Block only Adult/XXX content"
      // So we should block XXX content when this setting is active
      if (isMovie && user.settings.maxMovieRating === 'Adult') {
        console.log(`Blocking XXX movie content: ${title}`);
        return false;
      }
      
      // For TV: if no maxTvRating is set (empty), allow all TV content
      // But if a rating is set and it's not allowing adult content, block it
      if (isTv && user.settings.maxTvRating && user.settings.maxTvRating !== 'XXX_ALLOWED') {
        console.log(`Blocking adult TV content: ${title}`);
        return false;
      }
      
      // If it's TV and no rating restriction, allow it
      if (isTv && !user.settings.maxTvRating) {
        console.log(`Allowing adult TV content (no restriction): ${title}`);
        return true;
      }
    }

    // If no rating limits are set, allow non-adult content
    if (!user.settings.maxMovieRating && !user.settings.maxTvRating) {
      return true;
    }

    // Movie filtering based on user setting
    if (isMovie && user.settings.maxMovieRating) {
      const maxRating = user.settings.maxMovieRating;
      const genreIds = result.genre_ids || [];
      
      if (maxRating === 'G') {
        if (genreIds.some((id: number) => [28, 12, 53, 27, 80, 10752, 37].includes(id))) {
          return false;
        }
      }
      
      if (maxRating === 'PG') {
        if (genreIds.some((id: number) => [27, 80, 10752, 53].includes(id))) {
          return false;
        }
      }
      
      if (maxRating === 'PG-13') {
        if (genreIds.includes(27)) {
          return false;
        }
      }
    }

    // TV filtering based on user setting
    if (isTv && user.settings.maxTvRating) {
      const maxRating = user.settings.maxTvRating;
      const genreIds = result.genre_ids || [];
      
      if (maxRating === 'TV-Y' || maxRating === 'TV-G') {
        if (genreIds.some((id: number) => [28, 12, 53, 27, 80, 10752, 37, 18].includes(id))) {
          return false;
        }
      }
      
      if (maxRating === 'TV-PG') {
        if (genreIds.some((id: number) => [27, 80, 10752, 53, 18].includes(id))) {
          return false;
        }
      }
      
      if (maxRating === 'TV-14') {
        if (genreIds.includes(18)) {
          return false;
        }
      }
    }

    return true;
  });
  
  console.log('Total results after filtering:', filtered.length);
  console.log('=== END FILTER DEBUG ===');
  return filtered;
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
