import TheMovieDb from '@server/api/themoviedb';
import Media from '@server/entity/Media';
import logger from '@server/logger';
import {
  mapCastCredits,
  mapCrewCredits,
  mapPersonDetails,
} from '@server/models/Person';
import { Router } from 'express';
import { createTmdbWithRegionLanguage } from './discover';

const personRoutes = Router();

personRoutes.get('/:id', async (req, res, next) => {
  const tmdb = createTmdbWithRegionLanguage(req.user);

  try {
    const person = await tmdb.getPerson({
      personId: Number(req.params.id),
      language: (req.query.language as string) ?? req.locale,
    });
    return res.status(200).json(mapPersonDetails(person));
  } catch (e) {
    logger.debug('Something went wrong retrieving person', {
      label: 'API',
      errorMessage: e.message,
      personId: req.params.id,
    });
    return next({
      status: 500,
      message: 'Unable to retrieve person.',
    });
  }
});

personRoutes.get('/:id/combined_credits', async (req, res, next) => {
  const tmdb = createTmdbWithRegionLanguage(req.user);

  try {
    const combinedCredits = await tmdb.getPersonCombinedCredits({
      personId: Number(req.params.id),
      language: (req.query.language as string) ?? req.locale,
    });

    // Apply certification filtering for restricted users (v1.5.8)
    // Filter by getting allowed IDs from filtering methods, then keeping matching items
    let filteredCast = combinedCredits.cast;
    let filteredCrew = combinedCredits.crew;
    
    if (req.user?.settings?.maxMovieRating && req.user.settings.maxMovieRating !== 'Adult') {
      // Separate movies and TV shows
      const castMovies = filteredCast.filter(item => item.media_type === 'movie');
      const castTv = filteredCast.filter(item => item.media_type === 'tv');
      const crewMovies = filteredCrew.filter(item => item.media_type === 'movie');
      const crewTv = filteredCrew.filter(item => item.media_type === 'tv');
      
      // Get filtered movie IDs
      const filteredCastMovieResults = await tmdb.filterMoviesByCertification(castMovies as any);
      const filteredCrewMovieResults = await tmdb.filterMoviesByCertification(crewMovies as any);
      const allowedMovieIds = new Set([
        ...filteredCastMovieResults.map((m: any) => m.id),
        ...filteredCrewMovieResults.map((m: any) => m.id)
      ]);
      
      // Get filtered TV IDs if user has TV restrictions
      let allowedTvIds = new Set(castTv.map(t => t.id).concat(crewTv.map(t => t.id)));
      if (req.user.settings.maxTvRating && req.user.settings.maxTvRating !== 'Adult') {
        const filteredCastTvResults = await tmdb.filterTvByRating(castTv as any);
        const filteredCrewTvResults = await tmdb.filterTvByRating(crewTv as any);
        allowedTvIds = new Set([
          ...filteredCastTvResults.map((t: any) => t.id),
          ...filteredCrewTvResults.map((t: any) => t.id)
        ]);
      }
      
      // Filter original arrays by allowed IDs
      filteredCast = filteredCast.filter(item => 
        item.media_type === 'movie' ? allowedMovieIds.has(item.id) : allowedTvIds.has(item.id)
      );
      filteredCrew = filteredCrew.filter(item =>
        item.media_type === 'movie' ? allowedMovieIds.has(item.id) : allowedTvIds.has(item.id)
      );
    }

    const castMedia = await Media.getRelatedMedia(
      filteredCast.map((result) => result.id)
    );

    const crewMedia = await Media.getRelatedMedia(
      filteredCrew.map((result) => result.id)
    );

    return res.status(200).json({
      cast: filteredCast
        .map((result) =>
          mapCastCredits(
            result,
            castMedia.find(
              (med) =>
                med.tmdbId === result.id && med.mediaType === result.media_type
            )
          )
        )
        .filter((item) => !item.adult),
      crew: filteredCrew
        .map((result) =>
          mapCrewCredits(
            result,
            crewMedia.find(
              (med) =>
                med.tmdbId === result.id && med.mediaType === result.media_type
            )
          )
        )
        .filter((item) => !item.adult),
      id: combinedCredits.id,
    });
  } catch (e) {
    logger.debug('Something went wrong retrieving combined credits', {
      label: 'API',
      errorMessage: e.message,
      personId: req.params.id,
    });
    return next({
      status: 500,
      message: 'Unable to retrieve combined credits.',
    });
  }
});

export default personRoutes;
