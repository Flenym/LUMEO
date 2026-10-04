import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { paginate, paginateCursor, Paginated, CursorPaginated } from '../../common/pagination';
import { assertValidUsername } from '../../common/username';

export interface AppUser {
  id: string;
  username: string; // handle без @
  email: string | null;
  createdAt: string;
}

// In-memory репозиторий с интерфейсом под замену на TypeORM.
// TODO(db): SQL — таблица users (unique lower(username), unique lower(email)).
@Injectable()
export class UsersService {
  private users = new Map<string, AppUser>();
  private idByUsername = new Map<string, string>(); // lower(handle) -> id

  /** Создать пользователя Tier1 (username с правилами @username, мин 4). */
  create(username: string, email?: string): AppUser {
    let handle: string;
    try {
      handle = assertValidUsername(username);
    } catch {
      throw new BadRequestException({
        code: 'INVALID_USERNAME',
        message: 'username must be min 4 chars of [a-zA-Z0-9_.-] with optional leading @',
      });
    }
    if (this.idByUsername.has(handle.toLowerCase())) {
      throw new BadRequestException({ code: 'USERNAME_TAKEN', message: 'username taken' });
    }
    const user: AppUser = {
      id: randomUUID(),
      username: handle,
      email: email?.trim().toLowerCase() || null,
      createdAt: new Date().toISOString(),
    };
    this.users.set(user.id, user);
    this.idByUsername.set(handle.toLowerCase(), user.id);
    return user;
  }

  list(page = 1, limit = 20): Paginated<AppUser> {
    return paginate([...this.users.values()], page, limit);
  }

  listCursor(cursor?: string, limit = 20): CursorPaginated<AppUser> {
    const arr = [...this.users.values()].sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1));
    return paginateCursor(arr, cursor, limit, (u) => u.id);
  }

  get(id: string): AppUser {
    const u = this.users.get(id);
    if (!u) throw new NotFoundException({ code: 'NOT_FOUND', message: 'user not found' });
    return u;
  }

  getByUsername(username: string): AppUser {
    const handle = (username ?? '').trim().replace(/^@/, '').toLowerCase();
    const id = this.idByUsername.get(handle);
    const u = (id && this.users.get(id)) || null;
    if (!u) throw new NotFoundException({ code: 'NOT_FOUND', message: 'user not found' });
    return u;
  }

  /** Поиск по username (подстрока, case-insensitive) — для Friends/search. */
  searchByUsername(q: string, limit = 20): AppUser[] {
    const needle = (q ?? '').trim().replace(/^@/, '').toLowerCase();
    if (!needle) return [];
    return [...this.users.values()]
      .filter((u) => u.username.toLowerCase().includes(needle))
      .slice(0, Math.min(100, Math.max(1, limit)));
  }
}
