import * as shared from '@yaguhae/shared';
import * as db from './generated/prisma/enums.js';

// packages/shared 의 enum 은 web 도 쓰므로 DB enum 과 값이 어긋나면 안 된다.
describe('shared enum ↔ Prisma enum', () => {
  const dbEnums = Object.entries(db);

  it('Prisma enum 이 shared 에 모두 있다', () => {
    const missing = dbEnums
      .map(([name]) => name)
      .filter((name) => !(name in shared));
    expect(missing).toEqual([]);
  });

  it.each(dbEnums)('%s 값이 같다', (name, values) => {
    expect((shared as Record<string, unknown>)[name]).toEqual(values);
  });
});
