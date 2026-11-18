import { randomUUID } from 'node:crypto';
import { PrismaPg } from '@prisma/adapter-pg';
import { Position, SLOTS_PER_GAME, TeamSide } from '@yaguhae/shared';
import { PrismaClient } from '../src/generated/prisma/client.js';

// 마이그레이션 SQL 에 직접 쓴 제약(부분 unique, check, 복합 FK)이 실제로 동작하는지 확인한다.
// 앱의 락·검증이 빠져도 DB 가 막아야 하는 것들이다 (docs/design/erd.md 5·7장).
// 실행마다 고유한 데이터를 만들고 끝나면 지운다.

const HOUR = 60 * 60 * 1000;
const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

const created = {
  users: [] as string[],
  games: [] as string[],
  regionCode: '',
  leagueId: '',
  stadiumId: '',
};

async function createUser() {
  const user = await prisma.user.create({
    data: { kakaoId: `test-${randomUUID()}` },
  });
  created.users.push(user.id);
  return user;
}

async function createGame(
  hostId: string,
  startsAt: Date,
  durationMs = 2 * HOUR,
) {
  const game = await prisma.game.create({
    data: {
      hostId,
      stadiumId: created.stadiumId,
      startsAt,
      endsAt: new Date(startsAt.getTime() + durationMs),
      fee: 10000,
      allowedGrades: ['DIV_4', 'ROOKIE'],
      bankName: '테스트은행',
      accountNumber: '000-0000-0000',
      accountHolder: '홍길동',
      slots: {
        create: Object.values(TeamSide).flatMap((side) =>
          Object.values(Position).map((position) => ({ side, position })),
        ),
      },
    },
    include: { slots: true },
  });
  created.games.push(game.id);
  return game;
}

function reserve(gameId: string, gameSlotId: string, userId: string) {
  return prisma.reservation.create({
    data: {
      gameId,
      gameSlotId,
      userId,
      depositorName: '홍길동',
      paymentDeadlineAt: new Date(Date.now() + 24 * HOUR),
    },
  });
}

describe('DB 제약', () => {
  const startsAt = new Date(Date.now() + 7 * 24 * HOUR);

  beforeAll(async () => {
    // 테스트 전용 지역 코드 (실제 행정코드와 겹치지 않는 값)
    created.regionCode = `T${String(Math.floor(Math.random() * 1e4)).padStart(4, '0')}`;
    await prisma.region.create({
      data: { code: created.regionCode, sido: '테스트', sigungu: '테스트구' },
    });
    const league = await prisma.league.create({
      data: { regionCode: created.regionCode, name: '테스트리그' },
    });
    created.leagueId = league.id;
    const stadium = await prisma.stadium.create({
      data: {
        leagueId: league.id,
        regionCode: created.regionCode,
        name: '테스트구장',
        status: 'APPROVED',
      },
    });
    created.stadiumId = stadium.id;
  });

  afterAll(async () => {
    await prisma.reservation.deleteMany({
      where: { gameId: { in: created.games } },
    });
    await prisma.gameSlot.deleteMany({
      where: { gameId: { in: created.games } },
    });
    await prisma.game.deleteMany({ where: { id: { in: created.games } } });
    await prisma.stadium.deleteMany({ where: { id: created.stadiumId } });
    await prisma.league.deleteMany({ where: { id: created.leagueId } });
    await prisma.region.deleteMany({ where: { code: created.regionCode } });
    await prisma.user.deleteMany({ where: { id: { in: created.users } } });
    await prisma.$disconnect();
  });

  it(`경기를 만들면 자리 ${SLOTS_PER_GAME}개가 생긴다`, async () => {
    const host = await createUser();
    const game = await createGame(host.id, startsAt);
    expect(game.slots).toHaveLength(SLOTS_PER_GAME);
  });

  describe('경기 시간: 2~3시간, 10분 단위', () => {
    it.each([
      ['2시간', 2 * HOUR, true],
      ['2시간 10분', 2 * HOUR + 10 * 60 * 1000, true],
      ['3시간', 3 * HOUR, true],
      ['1시간 50분', 2 * HOUR - 10 * 60 * 1000, false],
      ['2시간 5분', 2 * HOUR + 5 * 60 * 1000, false],
      ['3시간 10분', 3 * HOUR + 10 * 60 * 1000, false],
    ])('%s → %s', async (_label, duration, ok) => {
      const host = await createUser();
      const result = createGame(host.id, startsAt, duration);
      if (ok) await expect(result).resolves.toBeDefined();
      else await expect(result).rejects.toThrow(/games_duration_check/);
    });
  });

  it('자리 1개에 동시에 10명이 예약하면 1명만 성공한다', async () => {
    const host = await createUser();
    const game = await createGame(host.id, startsAt);
    const slot = game.slots[0];
    const players = await Promise.all(
      Array.from({ length: 10 }, () => createUser()),
    );

    const results = await Promise.allSettled(
      players.map((p) => reserve(game.id, slot.id, p.id)),
    );

    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    // 나머지는 모두 unique 위반(P2002)이어야 한다. 다른 이유로 실패하면 테스트가 의미 없다.
    for (const r of results) {
      if (r.status === 'rejected')
        expect(r.reason).toMatchObject({ code: 'P2002' });
    }
  });

  it('취소된 예약의 자리는 다시 예약할 수 있다', async () => {
    const host = await createUser();
    const game = await createGame(host.id, startsAt);
    const [a, b] = [await createUser(), await createUser()];
    const first = await reserve(game.id, game.slots[0].id, a.id);
    await prisma.reservation.update({
      where: { id: first.id },
      data: { status: 'CANCELLED', cancelledAt: new Date() },
    });
    await expect(
      reserve(game.id, game.slots[0].id, b.id),
    ).resolves.toBeDefined();
  });

  it('같은 경기에 두 자리를 예약할 수 없다', async () => {
    const host = await createUser();
    const game = await createGame(host.id, startsAt);
    const player = await createUser();
    await reserve(game.id, game.slots[0].id, player.id);
    await expect(
      reserve(game.id, game.slots[1].id, player.id),
    ).rejects.toThrow();
  });

  it('다른 경기의 자리를 가리키는 예약은 만들 수 없다 (복합 FK)', async () => {
    const host = await createUser();
    const [g1, g2] = [
      await createGame(host.id, startsAt),
      await createGame(host.id, startsAt),
    ];
    const player = await createUser();
    // FK 위반(P2003)
    await expect(
      reserve(g1.id, g2.slots[0].id, player.id),
    ).rejects.toMatchObject({
      code: 'P2003',
    });
  });

  it('EXPIRED 는 만료 사유가 있어야 한다', async () => {
    const host = await createUser();
    const game = await createGame(host.id, startsAt);
    const r = await reserve(game.id, game.slots[0].id, (await createUser()).id);
    await expect(
      prisma.reservation.update({
        where: { id: r.id },
        data: { status: 'EXPIRED' },
      }),
    ).rejects.toThrow(/reservations_expire_check/);
  });
});
