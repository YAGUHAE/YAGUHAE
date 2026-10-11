// .husky/pre-commit 에서 --concurrent false 로 실행하므로
// 위에서부터 차례로 돈다: 린트 자동 수정 → 포맷.
const quote = (files) => files.map((file) => `"${file}"`).join(' ');

/** @type {import('lint-staged').Configuration} */
const config = {
  'apps/server/**/*.ts': (files) =>
    `pnpm --filter @yaguhae/server exec oxlint --type-aware --fix ${quote(files)}`,
  'apps/web/**/*.{ts,tsx,js,jsx,mjs}': (files) =>
    `pnpm --filter @yaguhae/web exec eslint --fix ${quote(files)}`,
  '*': 'prettier --write --ignore-unknown',
};

export default config;
