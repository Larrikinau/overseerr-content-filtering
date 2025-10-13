import TheMovieDb from '@server/api/themoviedb';
import Media from '@server/entity/Media';
import logger from '@server/logger';
import { mapCollection } from '@server/models/Collection';
import { Router } from 'express';
import { createTmdbWithRegionLanguage } from './discover';

const collectionRoutes = Router();

collectionRoutes.get<{ id: string }>('/:id', async (req, res, next) => {
  const tmdb = createTmdbWithRegionLanguage(req.user);

  try {
    const collection = await tmdb.getCollection({
      collectionId: Number(req.params.id),
      language: (req.query.language as string) ?? req.locale,
    });

    // Apply certification filtering for restricted users (v1.5.8)
    let filteredParts = collection.parts;
    if (req.user?.settings?.maxMovieRating && req.user.settings.maxMovieRating !== 'Adult') {
      filteredParts = await tmdb.filterMoviesByCertification(collection.parts);
    }

    const media = await Media.getRelatedMedia(
      filteredParts.map((part) => part.id)
    );

    return res.status(200).json(mapCollection({ ...collection, parts: filteredParts }, media));
  } catch (e) {
    logger.debug('Something went wrong retrieving collection', {
      label: 'API',
      errorMessage: e.message,
      collectionId: req.params.id,
    });
    return next({
      status: 500,
      message: 'Unable to retrieve collection.',
    });
  }
});

export default collectionRoutes;
