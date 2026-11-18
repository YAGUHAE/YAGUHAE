import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';

// 로컬에서는 apps/server/.env 를 읽는다. 운영 컨테이너는 환경변수로 받으므로 파일이 없어도 된다.
try {
  process.loadEnvFile();
} catch {
  // .env 없음
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(process.env.PORT ?? 4000);
}
await bootstrap();
