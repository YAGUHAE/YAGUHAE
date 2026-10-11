/**
 * 커밋 메시지 규칙 (docs/git-convention.md 참고)
 *   <type>(<scope>): <subject>
 *   예) feat(server): 카카오 로그인 추가
 *
 * @type {import('@commitlint/types').UserConfig}
 */
const config = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'design',
        'refactor',
        'style',
        'docs',
        'test',
        'chore',
        'ci',
        'perf',
        'revert',
      ],
    ],
    // 어느 앱/패키지의 변경인지 항상 밝힌다.
    'scope-empty': [2, 'never'],
    'scope-enum': [2, 'always', ['server', 'web', 'shared', 'config', 'repo']],
    // 제목은 한글로 쓰므로 대소문자 규칙은 끈다.
    'subject-case': [0],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 72],
    'body-max-line-length': [0],
  },
};

export default config;
