import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';

// e2e 는 실제 DB 에 붙는다. 로컬은 .env 의 DATABASE_URL, CI 는 환경변수를 쓴다.
try {
  process.loadEnvFile();
} catch {
  // .env 없음
}

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    globals: true,
    root: './',
    include: ['**/*.e2e-spec.ts'],
  },
});
