import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';

// Blue-Green 배포 중에는 두 컨테이너가 같은 DB 에 붙는다.
// 컨테이너당 커넥션 수를 제한해 Supabase pooler 한도를 넘지 않게 한다. (docs/infra.md 3.5)
const DEFAULT_POOL_MAX = 10;

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleDestroy {
  constructor() {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) {
      throw new Error(
        'DATABASE_URL 환경변수가 없습니다. apps/server/.env.example 을 참고하세요.',
      );
    }
    super({
      adapter: new PrismaPg({
        connectionString,
        max: Number(process.env.DATABASE_POOL_MAX ?? DEFAULT_POOL_MAX),
      }),
    });
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
