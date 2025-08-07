import ExternalAPI from '@server/api/externalapi';
import cacheManager from '@server/lib/cache';
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
  
  private getMovieCertification(): { [key: string]: string } {
    if (!this.maxMovieRating) return {}; // No restrictions
    
    // Correct logic: maxMovieRating is the MAXIMUM allowed rating
    // "G" = Allow only G-rated content
    // "PG" = Allow G and PG-rated content (block PG-13 and above)
    // "PG-13" = Allow G, PG, and PG-13 content (block R and above)
    // "R" = Allow G, PG, PG-13, and R content (block Adult/XXX)
    // "Adult" = Allow all content including Adult/XXX
    
    if (this.maxMovieRating === 'G') {
      return {
        'certification_country': 'US',
        'certification': 'G'
      };
    }
    
    return {
      'certification_country': 'US',
      'certification.lte': this.maxMovieRating
    };
  }
  
  private getTvCertification(): { [key: string]: string } {
    if (!this.maxTvRating) return {}; // No restrictions
    
    // TMDB TV Discover API uses "certification" parameter differently than movies
    // It accepts exact certification values, not "certification.lte"
    // Also, TMDB uses "certification_country" to specify the country
    
    // Map movie-style ratings to TV ratings for consistency in the UI
    // These are the exact TV rating values used by TMDB for US content
    const tvRatingMapping: { [key: string]: string[] } = {
      'G': ['TV-Y', 'TV-Y7', 'TV-G'],
      'PG': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG'], 
      'PG-13': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG', 'TV-14'],
      'R': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG', 'TV-14'],
      'Adult': ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG', 'TV-14', 'TV-MA']
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
    if (this.curatedMinVotes) {
      params['vote_count.gte'] = this.curatedMinVotes.toString();
    }
    
    // Apply admin-configured minimum rating if set
    if (this.curatedMinRating !== null && this.curatedMinRating !== undefined) {
      params['vote_average.gte'] = this.curatedMinRating.toString();
    }
    
    return params;
  }
  
  private async filterUnratedMovies(movies: any[]): Promise<any[]> {
    if (!this.maxMovieRating) return movies;
    
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
            (release: any) => release.certification && release.certification.trim() !== ''
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
    
    const filteredTvShows = [];
    
    for (const tvShow of tvShows) {
      try {
        // Get detailed TV show info to check for content ratings
        const details = await this.getTvShow({ tvId: tvShow.id });
        
        // Check if TV show has US content rating
        const usContentRating = details.content_ratings?.results?.find(
          (rating: any) => rating.iso_3166_1 === 'US'
        );
        
        if (usContentRating && usContentRating.rating && usContentRating.rating.trim() !== '') {
          // TV show has rating data - include it (TMDB filter already handled appropriateness)
          filteredTvShows.push(tvShow);
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

      // Apply unrated movie filtering when rating restrictions are enabled
      if (this.maxMovieRating) {
        data.results = await this.filterUnratedMovies(data.results);
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

      // Apply unrated movie filtering when rating restrictions are enabled
      if (this.maxMovieRating) {
        data.results = await this.filterUnratedMovies(data.results);
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

      // Apply unrated TV filtering when rating restrictions are enabled
      if (this.maxTvRating) {
        data.results = await this.filterUnratedTv(data.results);
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

      // Apply unrated TV filtering when rating restrictions are enabled
      if (this.maxTvRating) {
        data.results = await this.filterUnratedTv(data.results);
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

      const curatedFilters = this.getCuratedFilteringParams();
      
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

      // NEW: Post-process to filter out unrated movies when rating restrictions are enabled
      if (this.maxMovieRating) {
        data.results = await this.filterUnratedMovies(data.results);
      }

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

      const curatedFilters = this.getCuratedFilteringParams();
      
      const data = await this.get<TmdbSearchTvResponse>('/discover/tv', {
        params: {
          sort_by: sortBy,
          page,
          include_adult: this.shouldIncludeAdult(),
          ...this.getTvCertification(),
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

      // Post-process to filter out unrated TV shows when rating restrictions are enabled
      if (this.maxTvRating) {
        data.results = await this.filterUnratedTv(data.results);
      }

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
      const data = await this.get<TmdbUpcomingMoviesResponse>(
        '/movie/upcoming',
        {
          params: {
            page,
            language,
            region: this.region,
            originalLanguage: this.originalLanguage,
          },
        }
      );

      return data;
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
      // Ensure trending calls respect filtering preferences
      const params = {
        page,
        language,
        region: this.region,
        include_adult: this.shouldIncludeAdult(),
        ...this.getMovieCertification(),
        ...this.getCuratedFilteringParams(),
      };

      const data = await this.get<TmdbSearchMultiResponse>(
        `/trending/all/${timeWindow}`,
        {
          params,
        }
      );

      return data;
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
}

export default TheMovieDb;
