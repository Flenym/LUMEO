import { Injectable, NestMiddleware } from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';

// Простейший in-memory rate limit: 300 req/мин на IP. TODO: заменить на Redis в проде.
const hits = new Map<string, { count: number; resetAt: number }>();
const WINDOW_MS = 60_000;
const MAX_HITS = 300;

@Injectable()
export class RateLimitMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const ip = req.ip ?? 'unknown';
    const now = Date.now();
    const slot = hits.get(ip);
    if (!slot || now > slot.resetAt) {
      hits.set(ip, { count: 1, resetAt: now + WINDOW_MS });
      return next();
    }
    slot.count += 1;
    if (slot.count > MAX_HITS) {
      res.status(429).json({ statusCode: 429, message: 'Too many requests', error: 'TooManyRequests' });
      return;
    }
    next();
  }
}
