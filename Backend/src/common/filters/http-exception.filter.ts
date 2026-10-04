import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus } from '@nestjs/common';
import { Request, Response } from 'express';

// Единый формат ошибок Tier1: { code, message, requestId }
// Плюс обратно совместимые поля statusCode/path/timestamp для старых клиентов.
function codeForStatus(status: number): string {
  if (status === 400) return 'BAD_REQUEST';
  if (status === 401) return 'UNAUTHORIZED';
  if (status === 403) return 'FORBIDDEN';
  if (status === 404) return 'NOT_FOUND';
  if (status === 409) return 'CONFLICT';
  if (status === 423) return 'LOCKED';
  if (status === 429) return 'TOO_MANY_REQUESTS';
  if (status >= 500) return 'INTERNAL_ERROR';
  return `HTTP_${status}`;
}

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request & { requestId?: string }>();
    const status =
      exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const payload = exception instanceof HttpException ? exception.getResponse() : null;
    let message: unknown = 'Internal server error';
    let code: string | undefined;
    if (typeof payload === 'string') {
      message = payload;
    } else if (payload && typeof payload === 'object') {
      const p = payload as Record<string, unknown>;
      if (p['message'] !== undefined) message = p['message'];
      if (typeof p['code'] === 'string') code = p['code'] as string;
      // class-validator отдаёт массив строк — склеиваем в одну.
      if (Array.isArray(message)) message = (message as unknown[]).join('; ');
    } else if (exception instanceof Error && (exception as Error & { code?: string }).code) {
      code = (exception as Error & { code?: string }).code;
      message = exception.message;
    } else if (exception instanceof Error) {
      message = exception.message || message;
    }
    const requestId = (req.requestId ?? req.headers['x-request-id'] ?? null) as string | null;
    res.status(status).json({
      code: code ?? codeForStatus(status),
      message,
      requestId,
      statusCode: status,
      error: exception instanceof Error ? exception.name : 'Error',
      path: req.url,
      timestamp: new Date().toISOString(),
    });
  }
}
