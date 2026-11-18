import { defineConfig } from 'prisma/config';

// 로컬에서는 apps/server/.env 를 읽는다. 운영·CI 는 환경변수로 받으므로 파일이 없어도 된다.
try {
  process.loadEnvFile();
} catch {
  // .env 없음
}

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    // generate 는 DB 접속이 필요 없으므로 값이 없어도 실패시키지 않는다.
    url: process.env.DATABASE_URL ?? '',
  },
});
