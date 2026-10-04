import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable, tap } from 'rxjs';

// Сквозной лог запросов: метод, путь, статус, длительность, requestId.
// RequestId проставляет RequestIdMiddleware; здесь только читаем и логируем.
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = ctx.switchToHttp().getRequest() as {
      method?: string;
      url?: string;
      requestId?: string;
    };
    const started = Date.now();
    const method = req.method ?? '?';
    const url = req.url ?? '?';
    const requestId = req.requestId ?? '-';
    return next.handle().pipe(
      tap({
        next: () => {
          // eslint-disable-next-line no-console
          console.log(`[http] ${method} ${url} ok ${Date.now() - started}ms req=${requestId}`);
        },
        error: (err: unknown) => {
          // eslint-disable-next-line no-console
          console.log(
            `[http] ${method} ${url} err ${Date.now() - started}ms req=${requestId} ${
              err instanceof Error ? err.message : 'unknown'
            }`,
          );
        },
      }),
    );
  }
}
