# @yaguhae/server

NestJS API 서버. DB 는 PostgreSQL(운영: Supabase), ORM 은 Prisma 다. 설계 배경은 [PRD 7장](../../docs/design/PRD.md), [인프라 설계](../../docs/infra.md) 참고.

## 로컬 실행

```bash
cp .env.example .env     # apps/server 에서
pnpm db:up               # 로컬 Postgres (compose.dev.yml)
pnpm db:deploy           # 마이그레이션 적용
pnpm dev                 # http://localhost:4000, /health 로 DB 연결 확인
```

루트에서는 `pnpm --filter @yaguhae/server <스크립트>` 로 실행한다. `pnpm db:down` 으로 DB 를 멈춘다 (데이터는 볼륨에 남는다).

## DB 스크립트

| 스크립트      | 하는 일                                                                       |
| ------------- | ----------------------------------------------------------------------------- |
| `db:generate` | Prisma 클라이언트 생성 (`src/generated/prisma`, git 제외). turbo 가 자동 실행 |
| `db:migrate`  | `schema.prisma` 변경으로 마이그레이션 생성·적용 (`prisma migrate dev`)        |
| `db:deploy`   | 쌓인 마이그레이션만 적용 (`prisma migrate deploy`). CI·배포와 같은 명령       |
| `db:studio`   | Prisma Studio                                                                 |
| `db:up/down`  | 로컬 Postgres 시작·정지                                                       |

## 스키마 변경 규칙

1. `prisma/schema.prisma` 를 고치고 `pnpm db:migrate --name <설명>` 으로 마이그레이션을 만든다. `prisma db push` 는 쓰지 않는다.
2. 마이그레이션 SQL(`prisma/migrations/`)도 함께 커밋한다. 빠뜨리면 CI 의 스키마 드리프트 검사가 실패한다.
3. 배포 중에는 이전 버전이 같은 DB 를 잠시 쓰므로 **하위 호환 변경만** 한다. (컬럼 추가 → 배포 → 이후 정리)
4. 부분 unique 인덱스처럼 스키마로 표현할 수 없는 제약은 `pnpm db:migrate --name <설명> --create-only` 로 만든 뒤 SQL 을 직접 고치고 `pnpm db:migrate` 로 적용한다.

## 트랜잭션

`@nestjs-cls/transactional` 을 쓴다. 서비스 메서드에 `@Transactional()` 을 붙이고, 쿼리는 `TransactionHost` 의 `tx` 로 실행한다.

```ts
import { Injectable } from '@nestjs/common';
import { Transactional, TransactionHost } from '@nestjs-cls/transactional';
import type { TransactionalAdapterPrisma } from '@nestjs-cls/transactional-adapter-prisma';
import type { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class ReservationService {
  constructor(
    private readonly txHost: TransactionHost<
      TransactionalAdapterPrisma<PrismaService>
    >,
  ) {}

  @Transactional()
  async reserve(positionId: string) {
    // 행 락은 raw SQL 로 건다. (PRD 7.3)
    await this.txHost.tx
      .$queryRaw`SELECT id FROM game_positions WHERE id = ${positionId} FOR UPDATE`;
    // ...
  }
}
```

## 테스트

- `pnpm test`: 단위 테스트
- `pnpm test:e2e`: 실제 DB 에 붙는다. `.env` 의 `DATABASE_URL` 이 가리키는 DB 가 떠 있어야 한다.
