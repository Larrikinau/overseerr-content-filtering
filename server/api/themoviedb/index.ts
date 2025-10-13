import ExternalAPI from '@server/api/externalapi';
import cacheManager from '@server/lib/cache';
import logger from '@server/logger';
import { sortBy } from 'lodash';
import type {
  TmdbCollection,
  TmdbCompanySearchResponse,
  TmdbExternalIdResponse,
  TmdbGenre,
  TmdbGenresResult,
  TmdbKeyword,
  TmdbKeywordSearchResponse,
  TmdbLanguage,
  TmdbMovieDetails,
  TmdbMovieResult,
  TmdbNetwork,
  TmdbPersonCombinedCredits,
  TmdbPersonDetails,
  TmdbProductionCompany,
  TmdbRegion,
  TmdbSearchMovieResponse,
  TmdbSearchMultiResponse,
  TmdbSearchTvResponse,
  TmdbSeasonWithEpisodes,
  TmdbTvDetails,
  TmdbTvResult,
  TmdbUpcomingMoviesResponse,
  TmdbWatchProviderDetails,
  TmdbWatchProviderRegion,
} from './interfaces';

interface SearchOptions {
  query: string;
  page?: number;
  includeAdult?: boolean;
  language?: string;
}

interface SingleSearchOptions extends SearchOptions {
  year?: number;
}

export type SortOptions =
  | 'popularity.asc'
  | 'popularity.desc'
  | 'release_date.asc'
  | 'release_date.desc'
  | 'revenue.asc'
  | 'revenue.desc'
  | 'primary_release_date.asc'
  | 'primary_release_date.desc'
  | 'original_title.asc'
  | 'original_title.desc'
  | 'vote_average.asc'
  | 'vote_average.desc'
  | 'vote_count.asc'
  | 'vote_count.desc'
  | 'first_air_date.asc'
  | 'first_air_date.desc';

interface DiscoverMovieOptions {
  page?: number;
  includeAdult?: boolean;
  language?: string;
  primaryReleaseDateGte?: string;
  primaryReleaseDateLte?: string;
  withRuntimeGte?: string;
  withRuntimeLte?: string;
  voteAverageGte?: string;
  voteAverageLte?: string;
  voteCountGte?: string;
  voteCountLte?: string;
  originalLanguage?: string;
  genre?: string;
  studio?: string;
  keywords?: string;
  sortBy?: SortOptions;
  watchRegion?: string;
  watchProviders?: string;
  skipCuratedFilters?: boolean;
}

interface DiscoverTvOptions {
  page?: number;
  language?: string;
  firstAirDateGte?: string;
  firstAirDateLte?: string;
  withRuntimeGte?: string;
  withRuntimeLte?: string;
  voteAverageGte?: string;
  voteAverageLte?: string;
  voteCountGte?: string;
  voteCountLte?: string;
  includeEmptyReleaseDate?: boolean;
  originalLanguage?: string;
  genre?: string;
  network?: number;
  keywords?: string;
  sortBy?: SortOptions;
  watchRegion?: string;
  watchProviders?: string;
  skipCuratedFilters?: boolean;
  skipCertificationForUnrestricted?: boolean;
  serverSideRatingFilter?: boolean;
}

class TheMovieDb extends ExternalAPI {
  private region?: string;
  private originalLanguage?: string;
  private maxMovieRating?: string;
  private maxTvRating?: string;
  private tmdbSortingMode?: string;
  private curatedMinVotes?: number;
  private curatedMinRating?: number | null;
  constructor({
    region,
    originalLanguage,
    maxMovieRating,
    maxTvRating,
    tmdbSortingMode,
    curatedMinVotes,
    curatedMinRating,
  }: { region?: string; originalLanguage?: string; maxMovieRating?: string; maxTvRating?: string; tmdbSortingMode?: string; curatedMinVotes?: number; curatedMinRating?: number | null } = {}) {
    const apiParams: Record<string, string> = {};
    
    // Only include API key if one is actually configured
    if (process.env.TMDB_API_KEY && process.env.TMDB_API_KEY !== 'YOUR_TMDB_API_KEY_HERE') {
      apiParams.api_key = process.env.TMDB_API_KEY;
    }
    
    super(
      'https://api.themoviedb.org/3',
      apiParams,
      {
        nodeCache: cacheManager.getCache('tmdb').data,
        rateLimit: {
          maxRequests: 20,
          maxRPS: 50,
        },
      }
    );
    this.region = region;
    this.originalLanguage = originalLanguage;
    this.maxMovieRating = maxMovieRating;
    this.maxTvRating = maxTvRating;
    this.tmdbSortingMode = tmdbSortingMode;
    this.curatedMinVotes = curatedMinVotes;
    this.curatedMinRating = curatedMinRating;
  }
  
  private shouldIncludeAdult(): boolean {
    // Include adult content only if no restriction is set (empty string)
    // If "Adult" is selected, we should NOT include adult content
    // Allow adult content only if the max movie rating allows it (R or no restrictions)
    // Only include adult content when NO rating restrictions are set (unrestricted)
    return !this.maxMovieRating || this.maxMovieRating === "";
  }
  
  // ========== GLOBAL CERTIFICATION CACHING (v1.5.1) ==========
  // Static cache shared across all instances for certification data
  private static certificationCache = new Map<string, { cert: string; expires: number }>();
  private static CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours
  private static BATCH_SIZE = 10; // Process in batches to respect rate limits
  
  /**
   * Get cached movie certification or fetch from API
   * @param movieId - TMDB movie ID
   * @returns US certification string (e.g., "PG-13") or null if not available
   */
  private async getCachedMovieCertification(movieId: number): Promise<string | null> {
    const cacheKey = `movie:${movieId}`;
    const cached = TheMovieDb.certificationCache.get(cacheKey);
    
    // Return cached value if not expired
    if (cached && cached.expires > Date.now()) {
      return cached.cert;
    }
    
    // Fetch from API
    try {
      const releaseDates = await this.get<any>(`/movie/${movieId}/release_dates`);
      const usRelease = releaseDates?.results?.find((r: any) => r.iso_3166_1 === 'US');
      const cert = usRelease?.release_dates?.[0]?.certification || '';
      
      // Cache the result
      TheMovieDb.certificationCache.set(cacheKey, {
        cert,
        expires: Date.now() + TheMovieDb.CACHE_TTL,
      });
      
      return cert || null;
    } catch (error) {
      return null; // Safe default: exclude on error
    }
  }
  
  /**
   * Get cached TV rating or fetch from API
   * @param tvId - TMDB TV show ID
   * @returns US TV rating string (e.g., "TV-14") or null if not available
   */
  private async getCachedTvRating(tvId: number): Promise<string | null> {
    const cacheKey = `tv:${tvId}`;
    const cached = TheMovieDb.certificationCache.get(cacheKey);
    
    // Return cached value if not expired
    if (cached && cached.expires > Date.now()) {
      return cached.cert;
    }
    
    // Fetch from API
    try {
      const ratings = await this.get<any>(`/tv/${tvId}/content_ratings`);
      const usRating = ratings?.results?.find((r: any) => r.iso_3166_1 === 'US');
      const rating = usRating?.rating || '';
      
      // Cache the result
      TheMovieDb.certificationCache.set(cacheKey, {
        cert: rating,
        expires: Date.now() + TheMovieDb.CACHE_TTL,
      });
      
      return rating || null;
    } catch (error) {
      return null; // Safe default: exclude on error
    }
  }
  
  /**
   * Get list of allowed movie certifications based on user's max rating
   * @returns Array of allowed certification strings
   */
  private getAllowedMovieCertifications(): string[] {
    const allRatings = ['G', 'PG', 'PG-13', 'R', 'NC-17'];
    
    if (!this.maxMovieRating) {
      return allRatings; // No restrictions
    }
    
    const maxIndex = allRatings.indexOf(this.maxMovieRating);
    if (maxIndex === -1) {
      return allRatings; // Unknown rating, allow all
    }
    
    return allRatings.slice(0, maxIndex + 1);
  }
  
  /**
   * Get list of allowed TV ratings based on user's max rating
   * @returns Array of allowed TV rating strings
   */
  private getAllowedTvRatings(): string[] {
    const allRatings = ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG', 'TV-14', 'TV-MA'];
    
    if (!this.maxTvRating) {
      return allRatings; // No restrictions
    }
    
    // Map movie-style ratings to TV ratings (for backwards compatibility)
    const ratingMap: { [key: string]: string } = {
      'G': 'TV-G',
      'PG': 'TV-PG',
      'PG-13': 'TV-14',
      'R': 'TV-14',
      'Adult': 'TV-MA'
    };
    
    const mappedRating = ratingMap[this.maxTvRating] || this.maxTvRating;
    const maxIndex = allRatings.indexOf(mappedRating);
    
    if (maxIndex === -1) {
      return allRatings; // Unknown rating, allow all
    }
    
    return allRatings.slice(0, maxIndex + 1);
  }
  
  /**
   * Filter movies by certification with caching and batching
   * @param movies - Array of movie results from TMDB
   * @returns Filtered array of movies that meet certification requirements
   * @public Exposed for use in search routes (Issue #13 fix)
   */
  public async filterMoviesByCertification(movies: TmdbMovieResult[]): Promise<TmdbMovieResult[]> {
    // Check if user has no restrictions (null, undefined, empty string, or 'Adult')
    // 'Adult' means block XXX porn, but allow all mainstream rated content (G through NC-17) and NR
    if (!this.maxMovieRating || this.maxMovieRating === 'Adult') {
      return movies; // No filtering needed
    }
    
    const allowedCertifications = this.getAllowedMovieCertifications();
    const filtered: TmdbMovieResult[] = [];
    
    // Process in batches to respect rate limits
    for (let i = 0; i < movies.length; i += TheMovieDb.BATCH_SIZE) {
      const batch = movies.slice(i, i + TheMovieDb.BATCH_SIZE);
      
      const batchPromises = batch.map(async (movie) => {
        const cert = await this.getCachedMovieCertification(movie.id);
        
        // If no certification data, exclude for restricted users (safe default)
        if (!cert || cert === '') {
          return null;
        }
        
        // Check if certification is within allowed range
        if (allowedCertifications.includes(cert)) {
          return movie;
        }
        return null;
      });
      
      const batchResults = await Promise.all(batchPromises);
      filtered.push(...batchResults.filter(m => m !== null) as TmdbMovieResult[]);
    }
    
    return filtered;
  }
  
  /**
   * Filter TV shows by rating with caching and batching
   * @param shows - Array of TV show results from TMDB
   * @returns Filtered array of TV shows that meet rating requirements
   * @public Exposed for use in search routes (Issue #13 fix)
   */
  public async filterTvByRating(shows: TmdbTvResult[]): Promise<TmdbTvResult[]> {
    // Check if user has no restrictions (null, undefined, empty string, or 'Adult')
    // 'Adult' means allow all TV content including TV-MA and NR
    if (!this.maxTvRating || this.maxTvRating === 'Adult') {
      return shows; // No filtering needed
    }
    
    const allowedRatings = this.getAllowedTvRatings();
    const filtered: TmdbTvResult[] = [];
    
    // Process in batches to respect rate limits
    for (let i = 0; i < shows.length; i += TheMovieDb.BATCH_SIZE) {
      const batch = shows.slice(i, i + TheMovieDb.BATCH_SIZE);
      
      const batchPromises = batch.map(async (show) => {
        const rating = await this.getCachedTvRating(show.id);
        
        // If no rating data, exclude for restricted users (safe default)
        if (!rating || rating === '') {
          return null;
        }
        
        // Check if rating is within allowed range
        if (allowedRatings.includes(rating)) {
          return show;
        }
        return null;
      });
      
      const batchResults = await Promise.all(batchPromises);
      filtered.push(...batchResults.filter(s => s !== null) as TmdbTvResult[]);
    }
    
    return filtered;
  }
  // ========== END GLOBAL CERTIFICATION CACHING ==========
  
  private getMovieCertification(): { [key: string]: string } {
    // No restrictions if undefined, null, or 'Adult'
    // 'Adult' means block XXX porn only, allow all mainstream content and NR
    if (!this.maxMovieRating || this.maxMovieRating === 'Adult') {
      return {}; // No certification filtering
    }
    
    // TMDB Discover API requires explicit certification list, not .lte
    // Map max rating to list of allowed certifications
    const movieRatingMapping: { [key: string]: string[] } = {
      'G': ['G'],
      'PG': ['G', 'PG'],
      'PG-13': ['G', 'PG', 'PG-13'],
      'R': ['G', 'PG', 'PG-13', 'R'],
    };
    
    const allowedRatings = movieRatingMapping[this.maxMovieRating];
    if (allowedRatings) {
      // Use pipe-separated values for multiple allowed certifications
      return {
        'certification_country': 'US',
        'certification': allowedRatings.join('|')
      };
    }
    
    return {}; // No restrictions if rating not recognized
  }
  
  private getTvCertification(): { [key: string]: string } {
    // No restrictions if undefined, null, or 'Adult'
    // 'Adult' means allow all TV content including TV-MA and NR
    if (!this.maxTvRating || this.maxTvRating === 'Adult') {
      return {}; // No certification filtering
    }
    
    // TMDB TV Discover API uses "certification" parameter differently than movies
    // It accepts exact certification values, not "certification.lte"
    // Also, TMDB uses "certification_country" to specify the country
    
    // Map movie-style ratings to TV ratings for consistency in the UI
    // These are the exact TV rating values used by TMDB for US content
    // Support both movie-style (G, PG, etc.) and TV-style (TV-G, TV-PG, etc.) ratings
    const tvRatingMapping: { [key: string]: string[] } = {
      // Movie-style ratings (legacy support)
      'G': ['TV-Y', 'TV-Y7', 'TV-G'],
      'PG': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG'], 
      'PG-13': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG', 'TV-14'],
      'R': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG', 'TV-14'],
      // TV-style ratings (primary - used by UI)
      'TV-Y': ['TV-Y'],
      'TV-Y7': ['TV-Y', 'TV-Y7'],
      'TV-G': ['TV-Y', 'TV-Y7', 'TV-G'],
      'TV-PG': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG'],
      'TV-14': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG', 'TV-14'],
      'TV-MA': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG', 'TV-14', 'TV-MA'],
    };
    
    const allowedRatings = tvRatingMapping[this.maxTvRating];
    if (allowedRatings) {
      // For TMDB Discover TV API, we need to specify the country and allowed certifications
      // Use pipe-separated values for multiple allowed certifications
      return {
        'certification_country': 'US',
        'certification': allowedRatings.join('|')
      };
    }
    
    // Fallback for direct TV rating values
    return {
      'certification_country': 'US',
      'certification': this.maxTvRating
    };
  }
  
  private getCuratedFilteringParams(): { [key: string]: string | undefined } {
    const params: { [key: string]: string | undefined } = {};
    
    // Always apply curated filtering when values are set (not just in 'curated' mode)
    // This ensures consistent quality filtering across all discovery and recommendation methods
    if (this.curatedMinVotes && this.curatedMinVotes > 0) {
      params['vote_count.gte'] = this.curatedMinVotes.toString();
    }
    
    // Apply admin-configured minimum rating if set
    if (this.curatedMinRating && this.curatedMinRating > 0) {
      params['vote_average.gte'] = this.curatedMinRating.toString();
    }
    
    return params;
  }
  
  private async filterUnratedMovies(movies: any[]): Promise<any[]> {
    if (!this.maxMovieRating) return movies;
    
    // Define rating order for comparison (G < PG < PG-13 < R < NC-17)
    const ratingOrder: { [key: string]: number } = {
      'G': 1,
      'PG': 2,
      'PG-13': 3,
      'R': 4,
      'NC-17': 5,
      'NR': 999, // Not Rated - filter these out
      'UR': 999  // Unrated - filter these out
    };
    
    const maxRatingOrder = ratingOrder[this.maxMovieRating] || 999;
    const filteredMovies = [];
    
    for (const movie of movies) {
      try {
        // Get detailed movie info to check for certification
        const details = await this.getMovie({ movieId: movie.id });
        
        // Check if movie has US certification
        const usCertification = details.release_dates?.results?.find(
          (country: any) => country.iso_3166_1 === 'US'
        );
        
        if (usCertification && usCertification.release_dates?.length > 0) {
          // Check if any release date has certification data
          const hasCertification = usCertification.release_dates.some(
            (release: any) => {
              const cert = release.certification?.trim();
              if (!cert || cert === '') {
                return false;
              }
              // If it's NR (Not Rated), check the type of restriction
              if (cert === 'NR') {
                // "Adult" means "Block XXX Porn only" - allow non-adult NR content
                if (this.maxMovieRating === 'Adult') {
                  return details.adult !== true;  // Only block if marked as adult
                }
                // G/PG/PG-13/R restrictions - block ALL NR content (safe default)
                return false;
              }
              // Has valid certification - include it
              return true;
            }
          );
          
          if (hasCertification) {
            // Movie has rating data - include it (TMDB filter already handled appropriateness)
            filteredMovies.push(movie);
          }
          // If no rating data - exclude it when strict filtering is enabled
        }
        
      } catch (error) {
        // If we can't get movie details, exclude it to be safe when filtering is enabled
        continue;
      }
    }
    
    return filteredMovies;
  }

  private async filterUnratedTv(tvShows: any[]): Promise<any[]> {
    if (!this.maxTvRating) return tvShows;
    
    // Define TV rating order for comparison
    const ratingOrder: { [key: string]: number } = {
      'TV-Y': 1,
      'TV-Y7': 2,
      'TV-G': 3,
      'TV-PG': 4,
      'TV-14': 5,
      'TV-MA': 6,
      'NR': 999, // Not Rated - filter these out
      'UR': 999  // Unrated - filter these out
    };
    
    // Map movie-style max rating to TV rating order
    const maxRatingMapping: { [key: string]: number } = {
      'G': 3,      // Allow up to TV-G
      'PG': 4,     // Allow up to TV-PG
      'PG-13': 5,  // Allow up to TV-14
      'R': 5,      // Allow up to TV-14 (R movies ~= TV-14)
      'Adult': 6   // Allow up to TV-MA
    };
    
    const maxRatingOrder = maxRatingMapping[this.maxTvRating] || 999;
    const filteredTvShows = [];
    
    for (const tvShow of tvShows) {
      try {
        // Get detailed TV show info to check for content ratings
        const details = await this.getTvShow({ tvId: tvShow.id });
        
        // Check if TV show has US content rating
        const usContentRating = details.content_ratings?.results?.find(
          (rating: any) => rating.iso_3166_1 === 'US'
        );
        
        if (usContentRating) {
          const rating = usContentRating.rating?.trim();
          if (rating && rating !== '') {
            // If it's NR (Not Rated), block it for ALL TV rating restrictions
            // (Note: TMDB TV shows don't have an 'adult' flag like movies,
            //  so we can't distinguish safe NR from adult NR content)
            if (rating === 'NR') {
              // Block ALL NR content when any TV rating restriction is set
              // Don't add to array - excludes the show
            } else {
              // Has valid TV rating - include it
              filteredTvShows.push(tvShow);
            }
          }
        }
        // If no rating data - exclude it when strict filtering is enabled
        
      } catch (error) {
        // If we can't get TV show details, exclude it to be safe when filtering is enabled
        continue;
      }
    }
    
    return filteredTvShows;
  }

  public searchMulti = async ({
    query,
    page = 1,
    includeAdult = false,
    language = 'en',
  }: SearchOptions): Promise<TmdbSearchMultiResponse> => {
    try {
      const data = await this.get<TmdbSearchMultiResponse>('/search/multi', {
        params: { query, page, include_adult: this.shouldIncludeAdult(), language },
      });

      return data;
    } catch (e) {
      return {
        page: 1,
        results: [],
        total_pages: 1,
        total_results: 0,
      };
    }
  };

  public searchMovies = async ({
    query,
    page = 1,
    includeAdult = false,
    language = 'en',
    year,
  }: SingleSearchOptions): Promise<TmdbSearchMovieResponse> => {
    try {
      const data = await this.get<TmdbSearchMovieResponse>('/search/movie', {
        params: {
          query,
          page,
          include_adult: this.shouldIncludeAdult(),
          language,
          primary_release_year: year,
        },
      });

      return data;
    } catch (e) {
      return {
        page: 1,
        results: [],
        total_pages: 1,
        total_results: 0,
      };
    }
  };

  public searchTvShows = async ({
    query,
    page = 1,
    includeAdult = false,
    language = 'en',
    year,
  }: SingleSearchOptions): Promise<TmdbSearchTvResponse> => {
    try {
      const data = await this.get<TmdbSearchTvResponse>('/search/tv', {
        params: {
          query,
          page,
          include_adult: this.shouldIncludeAdult(),
          language,
          first_air_date_year: year,
        },
      });

      return data;
    } catch (e) {
      return {
        page: 1,
        results: [],
        total_pages: 1,
        total_results: 0,
      };
    }
  };

  public getPerson = async ({
    personId,
    language = 'en',
  }: {
    personId: number;
    language?: string;
  }): Promise<TmdbPersonDetails> => {
    try {
      const data = await this.get<TmdbPersonDetails>(`/person/${personId}`, {
        params: { language },
      });

      return data;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      throw new Error(`[TMDB] Failed to fetch person details: ${errorMessage}`);
    }
  };

  public getPersonCombinedCredits = async ({
    personId,
    language = 'en',
  }: {
    personId: number;
    language?: string;
  }): Promise<TmdbPersonCombinedCredits> => {
    try {
      const data = await this.get<TmdbPersonCombinedCredits>(
        `/person/${personId}/combined_credits`,
        {
          params: { language },
        }
      );

      return data;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      throw new Error(
        `[TMDB] Failed to fetch person combined credits: ${errorMessage}`
      );
    }
  };

  public getMovie = async ({
    movieId,
    language = 'en',
  }: {
    movieId: number;
    language?: string;
  }): Promise<TmdbMovieDetails> => {
    try {
      const data = await this.get<TmdbMovieDetails>(
        `/movie/${movieId}`,
        {
          params: {
            language,
            append_to_response:
              'credits,external_ids,videos,keywords,release_dates,watch/providers',
            include_video_language: language + ', en',
          },
        },
        43200
      );

      return data;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      throw new Error(`[TMDB] Failed to fetch movie details: ${errorMessage}`);
    }
  };

  public getTvShow = async ({
    tvId,
    language = 'en',
  }: {
    tvId: number;
    language?: string;
  }): Promise<TmdbTvDetails> => {
    try {
      const data = await this.get<TmdbTvDetails>(
        `/tv/${tvId}`,
        {
          params: {
            language,
            append_to_response:
              'aggregate_credits,credits,external_ids,keywords,videos,content_ratings,watch/providers',
            include_video_language: language + ', en',
          },
        },
        43200
      );

      return data;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      throw new Error(`[TMDB] Failed to fetch TV show details: ${errorMessage}`);
    }
  };

  public getTvSeason = async ({
    tvId,
    seasonNumber,
    language,
  }: {
    tvId: number;
    seasonNumber: number;
    language?: string;
  }): Promise<TmdbSeasonWithEpisodes> => {
    try {
      const data = await this.get<TmdbSeasonWithEpisodes>(
        `/tv/${tvId}/season/${seasonNumber}`,
        {
          params: {
            language,
            append_to_response: 'external_ids',
          },
        }
      );

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch TV show details: ${e.message}`);
    }
  };

  public getMovieRecommendations = async ({
    movieId,
    page = 1,
    language = 'en',
  }: {
    movieId: number;
    page?: number;
    language?: string;
  }): Promise<TmdbSearchMovieResponse> => {
    try {
      const params = {
        page,
        language,
        include_adult: this.shouldIncludeAdult(),
        ...this.getMovieCertification(),
        ...this.getCuratedFilteringParams(),
      };

      const data = await this.get<TmdbSearchMovieResponse>(
        `/movie/${movieId}/recommendations`,
        {
          params,
        }
      );

      // Apply server-side filtering with caching (v1.5.1 - fixes Issue #13)
      if (this.maxMovieRating) {
        data.results = await this.filterMoviesByCertification(data.results);
      }

      return data;
    } catch (e) {
      return {
        page: 1,
        total_results: 0,
        total_pages: 0,
        results: [],
      };
    }
  };

  public getSimilarMovies = async ({
    movieId,
    page = 1,
    language = 'en',
  }: {
    movieId: number;
    page?: number;
    language?: string;
  }): Promise<TmdbSearchMovieResponse> => {
    try {
      const params = {
        page,
        language,
        include_adult: this.shouldIncludeAdult(),
        ...this.getMovieCertification(),
        ...this.getCuratedFilteringParams(),
      };

      const data = await this.get<TmdbSearchMovieResponse>(
        `/movie/${movieId}/similar`,
        {
          params,
        }
      );

      // Apply server-side filtering with caching (v1.5.1 - fixes Issue #13)
      if (this.maxMovieRating) {
        data.results = await this.filterMoviesByCertification(data.results);
      }

      return data;
    } catch (e) {
      return {
        page: 1,
        total_results: 0,
        total_pages: 0,
        results: [],
      };
    }
  };

  public async getMoviesByKeyword({
    keywordId,
    page = 1,
    language = 'en',
  }: {
    keywordId: number;
    page?: number;
    language?: string;
  }): Promise<TmdbSearchMovieResponse> {
    try {
      const data = await this.get<TmdbSearchMovieResponse>(
        `/keyword/${keywordId}/movies`,
        {
          params: {
            page,
            language,
          },
        }
      );

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch movies by keyword: ${e.message}`);
    }
  }

  public getTvRecommendations = async ({
    tvId,
    page = 1,
    language = 'en',
  }: {
    tvId: number;
    page?: number;
    language?: string;
  }): Promise<TmdbSearchTvResponse> => {
    try {
      const params = {
        page,
        language,
        include_adult: this.shouldIncludeAdult(),
        ...this.getTvCertification(),
        ...this.getCuratedFilteringParams(),
      };

      const data = await this.get<TmdbSearchTvResponse>(
        `/tv/${tvId}/recommendations`,
        {
          params,
        }
      );

      // Apply server-side filtering with caching (v1.5.1 - fixes Issue #13)
      if (this.maxTvRating) {
        data.results = await this.filterTvByRating(data.results);
      }

      return data;
    } catch (e) {
      return {
        page: 1,
        total_results: 0,
        total_pages: 0,
        results: [],
      };
    }
  };

  public getSimilarTvShows = async ({
    tvId,
    page = 1,
    language = 'en',
  }: {
    tvId: number;
    page?: number;
    language?: string;
  }): Promise<TmdbSearchTvResponse> => {
    try {
      const params = {
        page,
        language,
        include_adult: this.shouldIncludeAdult(),
        ...this.getTvCertification(),
        ...this.getCuratedFilteringParams(),
      };

      const data = await this.get<TmdbSearchTvResponse>(`/tv/${tvId}/similar`, {
        params,
      });

      // Apply server-side filtering with caching (v1.5.1 - fixes Issue #13)
      if (this.maxTvRating) {
        data.results = await this.filterTvByRating(data.results);
      }

      return data;
    } catch (e) {
      return {
        page: 1,
        total_results: 0,
        total_pages: 0,
        results: [],
      };
    }
  };

  public getDiscoverMovies = async ({
    sortBy = 'popularity.desc',
    page = 1,
    includeAdult = false,
    language = 'en',
    primaryReleaseDateGte,
    primaryReleaseDateLte,
    originalLanguage,
    genre,
    studio,
    keywords,
    withRuntimeGte,
    withRuntimeLte,
    voteAverageGte,
    voteAverageLte,
    voteCountGte,
    voteCountLte,
    watchProviders,
    watchRegion,
    skipCuratedFilters = false,
  }: DiscoverMovieOptions = {}): Promise<TmdbSearchMovieResponse> => {
    try {
      const defaultFutureDate = new Date(
        Date.now() + 1000 * 60 * 60 * 24 * (365 * 1.5)
      )
        .toISOString()
        .split('T')[0];

      const defaultPastDate = new Date('1900-01-01')
        .toISOString()
        .split('T')[0];

      // Skip curated filters for upcoming/unreleased content as they often have no votes/ratings yet
      const curatedFilters = skipCuratedFilters ? {} : this.getCuratedFilteringParams();
      
      const data = await this.get<TmdbSearchMovieResponse>('/discover/movie', {
        params: {
          sort_by: sortBy,
          page,
          include_adult: this.shouldIncludeAdult(),
          ...this.getMovieCertification(),
          language,
          region: this.region,
          with_original_language:
            originalLanguage && originalLanguage !== 'all'
              ? originalLanguage
              : originalLanguage === 'all'
              ? undefined
              : this.originalLanguage,
          // Set our release date values, but check if one is set and not the other,
          // so we can force a past date or a future date. TMDB Requires both values if one is set!
          'primary_release_date.gte':
            !primaryReleaseDateGte && primaryReleaseDateLte
              ? defaultPastDate
              : primaryReleaseDateGte,
          'primary_release_date.lte':
            !primaryReleaseDateLte && primaryReleaseDateGte
              ? defaultFutureDate
              : primaryReleaseDateLte,
          with_genres: genre,
          with_companies: studio,
          with_keywords: keywords,
          'with_runtime.gte': withRuntimeGte,
          'with_runtime.lte': withRuntimeLte,
          'vote_average.gte': voteAverageGte || curatedFilters['vote_average.gte'],
          'vote_average.lte': voteAverageLte,
          'vote_count.gte': voteCountGte || curatedFilters['vote_count.gte'],
          'vote_count.lte': voteCountLte,
          watch_region: watchRegion,
          with_watch_providers: watchProviders,
        },
      });

      // Discover endpoints already use TMDB's certification filtering parameters
      // No need for additional post-filtering here
      return data;
    } catch (e) {
      return {
        page: 1,
        results: [],
        total_pages: 0,
        total_results: 0,
      };
    }
  };

  public getDiscoverTv = async ({
    sortBy = 'popularity.desc',
    page = 1,
    language = 'en',
    firstAirDateGte,
    firstAirDateLte,
    originalLanguage,
    genre,
    network,
    keywords,
    withRuntimeGte,
    withRuntimeLte,
    voteAverageGte,
    voteAverageLte,
    voteCountGte,
    voteCountLte,
    watchProviders,
    watchRegion,
    skipCuratedFilters = false,
    skipCertificationForUnrestricted = false,
    serverSideRatingFilter = false,
  }: DiscoverTvOptions = {}): Promise<TmdbSearchTvResponse> => {
    try {
      const defaultFutureDate = new Date(
        Date.now() + 1000 * 60 * 60 * 24 * (365 * 1.5)
      )
        .toISOString()
        .split('T')[0];

      const defaultPastDate = new Date('1900-01-01')
        .toISOString()
        .split('T')[0];

      // Skip curated filters for upcoming/unreleased content as they often have no votes/ratings yet
      const curatedFilters = skipCuratedFilters ? {} : this.getCuratedFilteringParams();
      
      // Skip TV certification only if skipCertificationForUnrestricted is true AND user has no TV restrictions
      // Also skip certification in API call if using server-side filtering
      const skipTvCert = (skipCertificationForUnrestricted && !this.maxTvRating) || serverSideRatingFilter;
      const tvCert = skipTvCert ? {} : this.getTvCertification();
      
      const data = await this.get<TmdbSearchTvResponse>('/discover/tv', {
        params: {
          sort_by: sortBy,
          page,
          include_adult: this.shouldIncludeAdult(),
          ...tvCert,
          language,
          region: this.region,
          with_original_language:
            originalLanguage && originalLanguage !== 'all'
              ? originalLanguage
              : originalLanguage === 'all'
              ? undefined
              : this.originalLanguage,
          // Set our first air date values, but check if one is set and not the other,
          // so we can force a past date or a future date. TMDB Requires both values if one is set!
          'first_air_date.gte':
            !firstAirDateGte && firstAirDateLte
              ? defaultPastDate
              : firstAirDateGte,
          'first_air_date.lte':
            !firstAirDateLte && firstAirDateGte
              ? defaultFutureDate
              : firstAirDateLte,
          with_genres: genre,
          with_networks: network,
          with_keywords: keywords,
          'with_runtime.gte': withRuntimeGte,
          'with_runtime.lte': withRuntimeLte,
          'vote_average.gte': voteAverageGte || curatedFilters['vote_average.gte'],
          'vote_average.lte': voteAverageLte,
          'vote_count.gte': voteCountGte || curatedFilters['vote_count.gte'],
          'vote_count.lte': voteCountLte,
          watch_region: watchRegion,
          with_watch_providers: watchProviders,
        },
      });

      // If server-side filtering is enabled AND user has TV restrictions, filter now
      if (serverSideRatingFilter && this.maxTvRating) {
        const filteredResults = await this.filterTvByRating(data.results);
        return {
          ...data,
          results: filteredResults,
        };
      }

      // Discover endpoints already use TMDB's certification filtering parameters
      // No need for additional post-filtering unless serverSideRatingFilter is enabled
      return data;
    } catch (e) {
      return {
        page: 1,
        results: [],
        total_pages: 0,
        total_results: 0,
      };
    }
  };

  public getUpcomingMovies = async ({
    page = 1,
    language = 'en',
  }: {
    page?: number;
    language?: string;
  } = {}): Promise<TmdbUpcomingMoviesResponse> => {
    try {
      // Use TMDB's native upcoming endpoint
      // Note: This endpoint doesn't support certification filtering
      const data = await this.get<TmdbUpcomingMoviesResponse>(
        '/movie/upcoming',
        {
          params: {
            page,
            language,
            region: this.region,
          },
        }
      );

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch upcoming movies: ${e.message}`);
    }
  };

  /**
   * Get upcoming movies with server-side certification filtering (v1.5.1)
   * Uses native TMDB /movie/upcoming endpoint and applies certification filtering via cache
   */
  public getUpcomingMoviesFiltered = async ({
    page = 1,
    language = 'en',
  }: {
    page?: number;
    language?: string;
  }): Promise<TmdbSearchMovieResponse> => {
    try {
      // Fetch from native upcoming endpoint
      const response = await this.get<TmdbUpcomingMoviesResponse>(
        '/movie/upcoming',
        {
          params: {
            page,
            language,
            region: this.region,
            include_adult: this.shouldIncludeAdult(),
          },
        }
      );

      // If user has no movie rating restriction, return all results
      if (!this.maxMovieRating || this.maxMovieRating === '') {
        return {
          page: response.page,
          total_pages: response.total_pages,
          total_results: response.total_results,
          results: response.results,
        };
      }

      // Apply server-side filtering with caching
      const filteredResults = await this.filterMoviesByCertification(response.results);

      return {
        page: response.page,
        total_pages: response.total_pages,
        total_results: response.total_results,
        results: filteredResults,
      };
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch upcoming movies: ${e.message}`);
    }
  };

  public getAllTrending = async ({
    page = 1,
    timeWindow = 'day',
    language = 'en',
  }: {
    page?: number;
    timeWindow?: 'day' | 'week';
    language?: string;
  } = {}): Promise<TmdbSearchMultiResponse> => {
    try {
      // Use TMDB's native /trending/all/ endpoint (matches vanilla Overseerr)
      // This returns popular content without curated filtering (v1.5.8 fix)
      const data = await this.get<TmdbSearchMultiResponse>(
        `/trending/all/${timeWindow}`,
        {
          params: {
            page,
            language,
            region: this.region,
          },
        }
      );

      // Apply curated filtering first (vote count, rating)
      let filteredResults = data.results;
      
      // Filter by curated settings if they exist
      if (this.curatedMinVotes && this.curatedMinVotes > 0) {
        filteredResults = filteredResults.filter((r: any) => 
          (r.vote_count || 0) >= this.curatedMinVotes!
        );
      }
      
      if (this.curatedMinRating && this.curatedMinRating > 0) {
        filteredResults = filteredResults.filter((r: any) => 
          (r.vote_average || 0) >= this.curatedMinRating!
        );
      }
      
      // Then apply certification filtering
      if (this.maxMovieRating || this.maxTvRating) {
        const movies = filteredResults.filter((r: any) => r.media_type === 'movie');
        const tvShows = filteredResults.filter((r: any) => r.media_type === 'tv');
        const others = filteredResults.filter((r: any) => r.media_type !== 'movie' && r.media_type !== 'tv');
        
        // Filter movies if user has movie restrictions
        const filteredMovies = this.maxMovieRating && this.maxMovieRating !== 'Adult'
          ? await this.filterMoviesByCertification(movies as any[])
          : movies;
          
        // Filter TV shows if user has TV restrictions  
        const filteredTv = this.maxTvRating && this.maxTvRating !== 'Adult'
          ? await this.filterTvByRating(tvShows as any[])
          : tvShows;
          
        filteredResults = [...filteredMovies, ...filteredTv, ...others];
      }

      return {
        ...data,
        results: filteredResults,
      };
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch all trending: ${e.message}`);
    }
  };

  public getMovieTrending = async ({
    page = 1,
    timeWindow = 'day',
    language = 'en',
  }: {
    page?: number;
    timeWindow?: 'day' | 'week';
    language?: string;
  } = {}): Promise<TmdbSearchMovieResponse> => {
    try {
      const params = {
        page,
        language,
        region: this.region,
        include_adult: this.shouldIncludeAdult(),
        ...this.getMovieCertification(),
        ...this.getCuratedFilteringParams(),
      };

      const data = await this.get<TmdbSearchMovieResponse>(
        `/trending/movie/${timeWindow}`,
        {
          params,
        }
      );

      // Apply unrated movie filtering when rating restrictions are enabled
      if (this.maxMovieRating) {
        data.results = await this.filterUnratedMovies(data.results);
      }

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch movie trending: ${e.message}`);
    }
  };

  public getTvTrending = async ({
    page = 1,
    timeWindow = 'day',
    language = 'en',
  }: {
    page?: number;
    timeWindow?: 'day' | 'week';
    language?: string;
  } = {}): Promise<TmdbSearchTvResponse> => {
    try {
      const params = {
        page,
        language,
        region: this.region,
        include_adult: this.shouldIncludeAdult(),
        ...this.getTvCertification(),
        ...this.getCuratedFilteringParams(),
      };

      const data = await this.get<TmdbSearchTvResponse>(
        `/trending/tv/${timeWindow}`,
        {
          params,
        }
      );

      // Apply unrated TV filtering when rating restrictions are enabled
      if (this.maxTvRating) {
        data.results = await this.filterUnratedTv(data.results);
      }

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch TV trending: ${e.message}`);
    }
  };

  public async getByExternalId({
    externalId,
    type,
    language = 'en',
  }:
    | {
        externalId: string;
        type: 'imdb';
        language?: string;
      }
    | {
        externalId: number;
        type: 'tvdb';
        language?: string;
      }): Promise<TmdbExternalIdResponse> {
    try {
      const data = await this.get<TmdbExternalIdResponse>(
        `/find/${externalId}`,
        {
          params: {
            external_source: type === 'imdb' ? 'imdb_id' : 'tvdb_id',
            language,
          },
        }
      );

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to find by external ID: ${e.message}`);
    }
  }

  public async getMediaByImdbId({
    imdbId,
    language = 'en',
  }: {
    imdbId: string;
    language?: string;
  }): Promise<TmdbMovieDetails | TmdbTvDetails> {
    try {
      const extResponse = await this.getByExternalId({
        externalId: imdbId,
        type: 'imdb',
      });

      if (extResponse.movie_results[0]) {
        const movie = await this.getMovie({
          movieId: extResponse.movie_results[0].id,
          language,
        });

        return movie;
      }

      if (extResponse.tv_results[0]) {
        const tvshow = await this.getTvShow({
          tvId: extResponse.tv_results[0].id,
          language,
        });

        return tvshow;
      }

      throw new Error(`No movie or show returned from API for ID ${imdbId}`);
    } catch (e) {
      throw new Error(
        `[TMDB] Failed to find media using external IMDb ID: ${e.message}`
      );
    }
  }

  public async getShowByTvdbId({
    tvdbId,
    language = 'en',
  }: {
    tvdbId: number;
    language?: string;
  }): Promise<TmdbTvDetails> {
    try {
      const extResponse = await this.getByExternalId({
        externalId: tvdbId,
        type: 'tvdb',
      });

      if (extResponse.tv_results[0]) {
        const tvshow = await this.getTvShow({
          tvId: extResponse.tv_results[0].id,
          language,
        });

        return tvshow;
      }

      throw new Error(`No show returned from API for ID ${tvdbId}`);
    } catch (e) {
      throw new Error(
        `[TMDB] Failed to get TV show using the external TVDB ID: ${e.message}`
      );
    }
  }

  public async getCollection({
    collectionId,
    language = 'en',
  }: {
    collectionId: number;
    language?: string;
  }): Promise<TmdbCollection> {
    try {
      const data = await this.get<TmdbCollection>(
        `/collection/${collectionId}`,
        {
          params: {
            language,
          },
        }
      );

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch collection: ${e.message}`);
    }
  }

  public async getRegions(): Promise<TmdbRegion[]> {
    try {
      const data = await this.get<TmdbRegion[]>(
        '/configuration/countries',
        {},
        86400 // 24 hours
      );

      const regions = sortBy(data, 'english_name');

      return regions;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch countries: ${e.message}`);
    }
  }

  public async getLanguages(): Promise<TmdbLanguage[]> {
    try {
      const data = await this.get<TmdbLanguage[]>(
        '/configuration/languages',
        {},
        86400 // 24 hours
      );

      const languages = sortBy(data, 'english_name');

      return languages;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch langauges: ${e.message}`);
    }
  }

  public async getStudio(studioId: number): Promise<TmdbProductionCompany> {
    try {
      const data = await this.get<TmdbProductionCompany>(
        `/company/${studioId}`
      );

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch movie studio: ${e.message}`);
    }
  }

  public async getNetwork(networkId: number): Promise<TmdbNetwork> {
    try {
      const data = await this.get<TmdbNetwork>(`/network/${networkId}`);

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch TV network: ${e.message}`);
    }
  }

  public async getMovieGenres({
    language = 'en',
  }: {
    language?: string;
  } = {}): Promise<TmdbGenre[]> {
    try {
      const data = await this.get<TmdbGenresResult>(
        '/genre/movie/list',
        {
          params: {
            language,
          },
        },
        86400 // 24 hours
      );

      if (
        !language.startsWith('en') &&
        data.genres.some((genre) => !genre.name)
      ) {
        const englishData = await this.get<TmdbGenresResult>(
          '/genre/movie/list',
          {
            params: {
              language: 'en',
            },
          },
          86400 // 24 hours
        );

        data.genres
          .filter((genre) => !genre.name)
          .forEach((genre) => {
            genre.name =
              englishData.genres.find(
                (englishGenre) => englishGenre.id === genre.id
              )?.name ?? '';
          });
      }

      const movieGenres = sortBy(
        data.genres.filter((genre) => genre.name),
        'name'
      );

      return movieGenres;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch movie genres: ${e.message}`);
    }
  }

  public async getTvGenres({
    language = 'en',
  }: {
    language?: string;
  } = {}): Promise<TmdbGenre[]> {
    try {
      const data = await this.get<TmdbGenresResult>(
        '/genre/tv/list',
        {
          params: {
            language,
          },
        },
        86400 // 24 hours
      );

      if (
        !language.startsWith('en') &&
        data.genres.some((genre) => !genre.name)
      ) {
        const englishData = await this.get<TmdbGenresResult>(
          '/genre/tv/list',
          {
            params: {
              language: 'en',
            },
          },
          86400 // 24 hours
        );

        data.genres
          .filter((genre) => !genre.name)
          .forEach((genre) => {
            genre.name =
              englishData.genres.find(
                (englishGenre) => englishGenre.id === genre.id
              )?.name ?? '';
          });
      }

      const tvGenres = sortBy(
        data.genres.filter((genre) => genre.name),
        'name'
      );

      return tvGenres;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch TV genres: ${e.message}`);
    }
  }

  public async getKeywordDetails({
    keywordId,
  }: {
    keywordId: number;
  }): Promise<TmdbKeyword> {
    try {
      const data = await this.get<TmdbKeyword>(
        `/keyword/${keywordId}`,
        undefined,
        604800 // 7 days
      );

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to fetch keyword: ${e.message}`);
    }
  }

  public async searchKeyword({
    query,
    page = 1,
  }: {
    query: string;
    page?: number;
  }): Promise<TmdbKeywordSearchResponse> {
    try {
      const data = await this.get<TmdbKeywordSearchResponse>(
        '/search/keyword',
        {
          params: {
            query,
            page,
          },
        },
        86400 // 24 hours
      );

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to search keyword: ${e.message}`);
    }
  }

  public async searchCompany({
    query,
    page = 1,
  }: {
    query: string;
    page?: number;
  }): Promise<TmdbCompanySearchResponse> {
    try {
      const data = await this.get<TmdbCompanySearchResponse>(
        '/search/company',
        {
          params: {
            query,
            page,
          },
        },
        86400 // 24 hours
      );

      return data;
    } catch (e) {
      throw new Error(`[TMDB] Failed to search companies: ${e.message}`);
    }
  }

  public async getAvailableWatchProviderRegions({
    language,
  }: {
    language?: string;
  }) {
    try {
      const data = await this.get<{ results: TmdbWatchProviderRegion[] }>(
        '/watch/providers/regions',
        {
          params: {
            language: language ?? this.originalLanguage,
          },
        },
        86400 // 24 hours
      );

      return data.results;
    } catch (e) {
      throw new Error(
        `[TMDB] Failed to fetch available watch regions: ${e.message}`
      );
    }
  }

  public async getMovieWatchProviders({
    language,
    watchRegion,
  }: {
    language?: string;
    watchRegion: string;
  }) {
    try {
      const data = await this.get<{ results: TmdbWatchProviderDetails[] }>(
        '/watch/providers/movie',
        {
          params: {
            language: language ?? this.originalLanguage,
            watch_region: watchRegion,
          },
        },
        86400 // 24 hours
      );

      return data.results;
    } catch (e) {
      throw new Error(
        `[TMDB] Failed to fetch movie watch providers: ${e.message}`
      );
    }
  }

  public async getTvWatchProviders({
    language,
    watchRegion,
  }: {
    language?: string;
    watchRegion: string;
  }) {
    try {
      const data = await this.get<{ results: TmdbWatchProviderDetails[] }>(
        '/watch/providers/tv',
        {
          params: {
            language: language ?? this.originalLanguage,
            watch_region: watchRegion,
          },
        },
        86400 // 24 hours
      );

      return data.results;
    } catch (e) {
      throw new Error(
        `[TMDB] Failed to fetch TV watch providers: ${e.message}`
      );
    }
  }

  /**
   * Mapping of network IDs to watch provider IDs for major streaming services
   * This allows us to fetch both TV shows (by network) and movies (by watch provider)
   */
  private readonly NETWORK_TO_PROVIDER: { [key: number]: number } = {
    213: 8,      // Netflix
    1024: 9,     // Amazon Prime Video
    2739: 337,   // Disney+
    3186: 384,   // HBO Max
    2552: 350,   // Apple TV+
    453: 15,     // Hulu
    4330: 531,   // Paramount+
    3353: 387,   // Peacock
  };

  /**
   * Get both movies and TV shows from a network/streaming service
   * For movies, we use watch providers; for TV, we use the network ID
   */
  public getNetworkAll = async ({
    networkId,
    page = 1,
    language = 'en',
    watchProviders,
    watchRegion,
  }: {
    networkId?: number;
    page?: number;
    language?: string;
    watchProviders?: string;
    watchRegion?: string;
  } = {}): Promise<TmdbSearchMultiResponse> => {
    try {
      const region = watchRegion || this.region || 'US';
      
      // Check if this network has a known watch provider mapping
      const providerIdForMovies = networkId ? this.NETWORK_TO_PROVIDER[networkId] : undefined;
      
      // Only skip curated filters if user has set both to 0 or undefined
      const shouldSkipCurated = !this.curatedMinVotes && !this.curatedMinRating;
      
      // Always fetch TV shows by network
      const tvPromise = this.getDiscoverTv({
        page: page,
        language,
        network: networkId,
        sortBy: 'popularity.desc',
        skipCuratedFilters: shouldSkipCurated,
      });
      
      // Fetch movies if we have a watch provider mapping
      const moviesPromise = providerIdForMovies
        ? this.getDiscoverMovies({
            page: page,
            language,
            watchProviders: providerIdForMovies.toString(),
            watchRegion: region,
            sortBy: 'popularity.desc',
            skipCuratedFilters: shouldSkipCurated,
          }).catch(() => ({ page: 1, results: [], total_pages: 0, total_results: 0 }))
        : Promise.resolve({ page: 1, results: [], total_pages: 0, total_results: 0 });
      
      const [moviesData, tvData] = await Promise.all([moviesPromise, tvPromise]);

      // Combine results from the same page of both TV and movies
      const allResults = [
        ...moviesData.results.map((movie) => ({ ...movie, media_type: 'movie' as const })),
        ...tvData.results.map((tv) => ({ ...tv, media_type: 'tv' as const })),
      ].sort((a, b) => b.popularity - a.popularity);

      // Return combined results with max total from TMDB
      const maxTotalPages = Math.max(moviesData.total_pages, tvData.total_pages);
      const maxTotalResults = moviesData.total_results + tvData.total_results;

      return {
        page,
        results: allResults,
        total_pages: maxTotalPages,
        total_results: maxTotalResults,
      };
    } catch (e) {
      throw new Error(
        `[TMDB] Failed to fetch network content: ${e.message}`
      );
    }
  };
}

export default TheMovieDb;
