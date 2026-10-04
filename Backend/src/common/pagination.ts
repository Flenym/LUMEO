// Пагинация: offset (?page/?limit) + cursor (?cursor/?limit).
// Offset: ?page=1&limit=20 -> { items, page, limit, total }
// Cursor: ?cursor=<lastId>&limit=20 -> { items, nextCursor, limit, total }
// Cursor — opaque id последнего элемента предыдущей страницы (для строковых id).

export interface Paginated<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
}

export interface CursorPaginated<T> {
  items: T[];
  nextCursor: string | null;
  limit: number;
  total: number;
}

export function paginate<T>(all: T[], page = 1, limit = 20): Paginated<T> {
  const safePage = Math.max(1, Math.floor(page) || 1);
  const safeLimit = Math.min(100, Math.max(1, Math.floor(limit) || 20));
  const start = (safePage - 1) * safeLimit;
  return { items: all.slice(start, start + safeLimit), page: safePage, limit: safeLimit, total: all.length };
}

/**
 * Cursor-пагинация по массиву с id-селектором.
 * @param all полный упорядоченный массив
 * @param cursor id последнего элемента предыдущей страницы (null — первая страница)
 * @param limit размер страницы (1..100)
 * @param getId селектор id элемента
 */
export function paginateCursor<T>(
  all: T[],
  cursor: string | null | undefined,
  limit = 20,
  getId: (item: T) => string = (x: T) => (x as unknown as { id: string }).id,
): CursorPaginated<T> {
  const safeLimit = Math.min(100, Math.max(1, Math.floor(limit) || 20));
  let start = 0;
  if (cursor) {
    const idx = all.findIndex((x) => getId(x) === cursor);
    start = idx >= 0 ? idx + 1 : 0;
  }
  const items = all.slice(start, start + safeLimit);
  const nextCursor = start + safeLimit < all.length && items.length > 0 ? getId(items[items.length - 1]) : null;
  return { items, nextCursor, limit: safeLimit, total: all.length };
}
