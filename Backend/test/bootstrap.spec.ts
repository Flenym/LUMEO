import { Test } from '@nestjs/testing';
import { AppModule } from '../src/app.module';

/**
 * Smoke: весь AppModule собирается целиком (все DI-зависимости резолвятся).
 * Ловит ошибки вида "AdminService needs WalletService, but WalletModule
 * doesn't export it" — unit-тесты сервисов их не видят, падает только
 * реальный старт сервера (npm run dev).
 */
describe('bootstrap', () => {
  test('AppModule compiles (all providers resolvable)', async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    expect(mod).toBeDefined();
    await mod.close();
  }, 30000);
});
