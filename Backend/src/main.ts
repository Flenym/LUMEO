import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import compression from 'compression';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { RequestIdMiddleware } from './common/interceptors/request-id.middleware';
import { RateLimitMiddleware } from './common/interceptors/rate-limit.middleware';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: false });

  // CloudPub заметка: сервер только слушает PORT (default 5267).
  // Публичный URL задаётся на iOS-клиенте через API_BASE_URL, здесь ничего менять не нужно.
  const port = Number(process.env.PORT || 5267);

  app.use(helmet());
  app.use(compression());
  app.enableCors({ origin: true, credentials: true });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new LoggingInterceptor());

  // request-id + простой rate limit как middleware
  const reqId = new RequestIdMiddleware();
  const rate = new RateLimitMiddleware();
  app.use((req: unknown, res: unknown, next: () => void) =>
    (reqId.use as (a: unknown, b: unknown, c: () => void) => void)(req, res, () =>
      (rate.use as (a: unknown, b: unknown, c: () => void) => void)(req, res, next),
    ),
  );

  // Версионирование: все REST под /api/v1, кроме /health и WS /ws.
  app.setGlobalPrefix('api/v1', { exclude: ['health'] });

  app.enableShutdownHooks();
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Lumeo backend listening on :${port}`);
}

void bootstrap();
