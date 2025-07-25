import PlexAPI from '@server/api/plexapi';
import dataSource, { getRepository } from '@server/datasource';
import DiscoverSlider from '@server/entity/DiscoverSlider';
import { Session } from '@server/entity/Session';
import { User } from '@server/entity/User';
import { startJobs } from '@server/job/schedule';
import notificationManager from '@server/lib/notifications';
import DiscordAgent from '@server/lib/notifications/agents/discord';
import EmailAgent from '@server/lib/notifications/agents/email';
import GotifyAgent from '@server/lib/notifications/agents/gotify';
import LunaSeaAgent from '@server/lib/notifications/agents/lunasea';
import PushbulletAgent from '@server/lib/notifications/agents/pushbullet';
import PushoverAgent from '@server/lib/notifications/agents/pushover';
import SlackAgent from '@server/lib/notifications/agents/slack';
import TelegramAgent from '@server/lib/notifications/agents/telegram';
import WebhookAgent from '@server/lib/notifications/agents/webhook';
import WebPushAgent from '@server/lib/notifications/agents/webpush';
import { getSettings } from '@server/lib/settings';
import logger from '@server/logger';
import clearCookies from '@server/middleware/clearcookies';
import routes from '@server/routes';
import imageproxy from '@server/routes/imageproxy';
import { getAppVersion } from '@server/utils/appVersion';
import restartFlag from '@server/utils/restartFlag';
import { getClientIp } from '@supercharge/request-ip';
import { TypeormStore } from 'connect-typeorm/out';
import cookieParser from 'cookie-parser';
import csurf from 'csurf';
import type { NextFunction, Request, Response } from 'express';
import express from 'express';
import * as OpenApiValidator from 'express-openapi-validator';
import type { Store } from 'express-session';
import session from 'express-session';
import next from 'next';
import path from 'path';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yamljs';

const API_SPEC_PATH = path.join(__dirname, '../overseerr-api.yml');

logger.info(`Starting Overseerr version ${getAppVersion()}`);
const dev = process.env.NODE_ENV !== 'production';
const app = next({ dev });
const handle = app.getRequestHandler();

app
  .prepare()
  .then(async () => {
    const dbConnection = await dataSource.initialize();

    // Run migrations in production or when explicitly requested (Docker support)
    // This ensures migrations run in Docker containers and production environments
    try {
      if (process.env.NODE_ENV === 'production' || process.env.RUN_MIGRATIONS === 'true') {
        logger.info('Running database migrations...', { label: 'Database' });
        
        // Ensure database directory exists and is writable
        const dbPath = process.env.CONFIG_DIRECTORY
          ? `${process.env.CONFIG_DIRECTORY}/db`
          : 'config/db';
        
        try {
          const fs = require('fs');
          if (!fs.existsSync(dbPath)) {
            fs.mkdirSync(dbPath, { recursive: true });
            logger.info(`Created database directory: ${dbPath}`, { label: 'Database' });
          }
        } catch (dirError: any) {
          logger.warn('Could not create database directory', { label: 'Database', error: dirError.message });
        }
        
        // Check if migrations are pending first
        const pendingMigrations = await dbConnection.showMigrations();
        if (pendingMigrations && (pendingMigrations as unknown as any[]).length > 0) {
          logger.info(`Found ${(pendingMigrations as unknown as any[]).length} pending migrations`, { label: 'Database' });
          
          // Log each pending migration
          (pendingMigrations as unknown as any[]).forEach((migration: any, index: number) => {
            logger.info(`Pending migration ${index + 1}: ${migration.name}`, { label: 'Database' });
          });
          
          await dbConnection.query('PRAGMA foreign_keys=OFF');
          const executedMigrations = await dbConnection.runMigrations();
          await dbConnection.query('PRAGMA foreign_keys=ON');
          
          if (executedMigrations && executedMigrations.length > 0) {
            logger.info(`Successfully executed ${executedMigrations.length} migrations`, { label: 'Database' });
            
            // Log each executed migration
            executedMigrations.forEach((migration, index) => {
              logger.info(`Executed migration ${index + 1}: ${migration.name}`, { label: 'Database' });
            });
          } else {
            logger.info('No migrations needed to be executed', { label: 'Database' });
          }
        } else {
          logger.info('Database schema is up to date', { label: 'Database' });
        }
        
        // Verify critical content filtering columns exist
        try {
          await dbConnection.query("SELECT tmdbSortingMode FROM user_settings LIMIT 1");
          logger.info('Content filtering columns verified', { label: 'Database' });
        } catch (verifyError: any) {
          logger.warn('Content filtering columns may not exist - this could indicate migration issues', { 
            label: 'Database', 
            error: verifyError.message 
          });
        }
        
      } else if (process.env.NODE_ENV === 'development' || process.env.NODE_ENV === 'test') {
        // In development, check if migrations are needed and log a warning
        try {
          const pendingMigrations = await dbConnection.showMigrations();
          if (pendingMigrations && (pendingMigrations as unknown as any[]).length > 0) {
            logger.warn(`Database has ${(pendingMigrations as unknown as any[]).length} pending migrations. Set RUN_MIGRATIONS=true to apply them.`, { label: 'Database' });
          }
        } catch (error: any) {
          logger.warn('Could not check migration status', { label: 'Database', error: error.message });
        }
      }
    } catch (error: any) {
      logger.error('Database migration error', { label: 'Database', error: error.message, stack: error.stack });
      throw error;
    }

    // Load Settings
    const settings = getSettings().load();
    restartFlag.initializeSettings(settings.main);

    // Migrate library types
    if (
      settings.plex.libraries.length > 1 &&
      !settings.plex.libraries[0].type
    ) {
      const userRepository = getRepository(User);
      const admin = await userRepository.findOne({
        select: { id: true, plexToken: true },
        where: { id: 1 },
      });

      if (admin) {
        logger.info('Migrating Plex libraries to include media type', {
          label: 'Settings',
        });

        const plexapi = new PlexAPI({ plexToken: admin.plexToken });
        await plexapi.syncLibraries();
      }
    }

    // Register Notification Agents
    notificationManager.registerAgents([
      new DiscordAgent(),
      new EmailAgent(),
      new GotifyAgent(),
      new LunaSeaAgent(),
      new PushbulletAgent(),
      new PushoverAgent(),
      new SlackAgent(),
      new TelegramAgent(),
      new WebhookAgent(),
      new WebPushAgent(),
    ]);

    // Start Jobs
    startJobs();

    // Bootstrap Discovery Sliders
    await DiscoverSlider.bootstrapSliders();

    const server = express();
    if (settings.main.trustProxy) {
      server.enable('trust proxy');
    }
    server.use(cookieParser());
    server.use(express.json());
    server.use(express.urlencoded({ extended: true }));
    server.use((req, _res, next) => {
      try {
        const descriptor = Object.getOwnPropertyDescriptor(req, 'ip');
        if (descriptor?.writable === true) {
          req.ip = getClientIp(req) ?? '';
        }
      } catch (e: any) {
        logger.error('Failed to attach the ip to the request', {
          label: 'Middleware',
          message: e.message,
        });
      } finally {
        next();
      }
    });
    if (settings.main.csrfProtection) {
      server.use(
        csurf({
          cookie: {
            httpOnly: true,
            sameSite: true,
            secure: !dev,
          },
        })
      );
      server.use((req, res, next) => {
        res.cookie('XSRF-TOKEN', req.csrfToken(), {
          sameSite: true,
          secure: !dev,
        });
        next();
      });
    }

    // Set up sessions
    const sessionRespository = getRepository(Session);
    server.use(
      '/api',
      session({
        secret: settings.clientId,
        resave: false,
        saveUninitialized: false,
        cookie: {
          maxAge: 1000 * 60 * 60 * 24 * 30,
          httpOnly: true,
          sameSite: settings.main.csrfProtection ? 'strict' : 'lax',
          secure: 'auto',
        },
        store: new TypeormStore({
          cleanupLimit: 2,
          ttl: 60 * 60 * 24 * 30,
        }).connect(sessionRespository) as Store,
      })
    );
    const apiDocs = YAML.load(API_SPEC_PATH);
    server.use('/api-docs', swaggerUi.serve, swaggerUi.setup(apiDocs));
    server.use(
      OpenApiValidator.middleware({
        apiSpec: API_SPEC_PATH,
        validateRequests: true,
      })
    );
    /**
     * This is a workaround to convert dates to strings before they are validated by
     * OpenAPI validator. Otherwise, they are treated as objects instead of strings
     * and response validation will fail
     */
    server.use((_req, res, next) => {
      const original = res.json;
      res.json = function jsonp(json) {
        return original.call(this, JSON.parse(JSON.stringify(json)));
      };
      next();
    });
    server.use('/api/v1', routes);

    // Do not set cookies so CDNs can cache them
    server.use('/imageproxy', clearCookies, imageproxy);

    server.get('*', (req, res) => handle(req, res));
    server.use(
      (
        err: { status: number; message: string; errors: string[] },
        _req: Request,
        res: Response,
        // We must provide a next function for the function signature here even though its not used
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        _next: NextFunction
      ) => {
        // format error
        res.status(err.status || 500).json({
          message: err.message,
          errors: err.errors,
        });
      }
    );

    const port = Number(process.env.PORT) || 5055;
    const host = process.env.HOST;
    if (host) {
      server.listen(port, host, () => {
        logger.info(`Server ready on ${host} port ${port}`, {
          label: 'Server',
        });
      });
    } else {
      server.listen(port, () => {
        logger.info(`Server ready on port ${port}`, {
          label: 'Server',
        });
      });
    }
  })
  .catch((err) => {
    logger.error(err.stack);
    process.exit(1);
  });
