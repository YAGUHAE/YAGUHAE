# Git 컨벤션

## 작업 흐름

1. 이슈를 만든다.
2. `dev` 에서 브랜치를 딴다. → `feat/#12-kakao-login`
3. 커밋하고 push 한 뒤 `dev` 로 PR 을 올린다.
4. 배포할 때 `dev` → `main` 으로 PR 을 올린다.

`main`, `dev` 에는 직접 push 할 수 없다 (pre-push 훅이 막는다).

## 브랜치 이름

```
<type>/#<이슈번호>-<설명>
```

- 설명은 영어 소문자, 숫자, `-` `.` `_` 만 쓴다.
- type 은 커밋 type 에 `hotfix`, `release` 를 더한 것이다.

```
feat/#12-kakao-login
fix/#30-header-layout
chore/#5-commit-convention
```

## 커밋 메시지

```
<type>(<scope>): <subject>

<body>  (선택)
```

```
feat(server): 카카오 로그인 추가
fix(web): 헤더 레이아웃 깨짐 수정
chore(repo): turbo 버전 업데이트
feat(server,web): 경기 일정 API 연동
```

### type

| type       | 용도                                  |
| ---------- | ------------------------------------- |
| `feat`     | 새 기능                               |
| `fix`      | 버그 수정                             |
| `design`   | UI·스타일 디자인 변경                 |
| `refactor` | 동작 변화 없는 코드 구조 개선         |
| `style`    | 포맷, 세미콜론 등 코드 의미 없는 변경 |
| `docs`     | 문서                                  |
| `test`     | 테스트 추가·수정                      |
| `chore`    | 빌드, 의존성, 설정 등 기타            |
| `ci`       | CI/CD 설정                            |
| `perf`     | 성능 개선                             |
| `revert`   | 커밋 되돌리기                         |

### scope (필수)

| scope    | 대상                                                          |
| -------- | ------------------------------------------------------------- |
| `server` | `apps/server`                                                 |
| `web`    | `apps/web`                                                    |
| `shared` | `packages/shared`                                             |
| `config` | `packages/typescript-config`, `packages/prettier-config`      |
| `repo`   | 루트 설정 (turbo, pnpm workspace, husky, commitlint, 문서 등) |

여러 곳을 함께 바꿨다면 `,` 로 나열한다. → `feat(server,web): ...`

### subject

- 한글로 쓴다.
- 헤더(`type(scope): subject`) 전체 72자 이하.
- 끝에 마침표를 찍지 않는다.

## Git 훅 (husky)

`pnpm install` 시 자동으로 설치된다.

| 훅           | 하는 일                                                                        |
| ------------ | ------------------------------------------------------------------------------ |
| `pre-commit` | 스테이징된 파일만 린트 자동 수정(server: oxlint, web: ESLint) 후 prettier 포맷 |
| `commit-msg` | commitlint 로 커밋 메시지 검사                                                 |
| `pre-push`   | `main`/`dev` 직접 push 차단, 브랜치 이름 검사, `turbo typecheck`               |

훅은 `.nvmrc` 의 Node 버전(24.21.0)에서 실행되어야 한다. 루트 `engines` 를 만족하지 못하면
pnpm 이 실패한다. nvm 을 쓴다면 기본 버전을 맞춰둔다.

```sh
nvm install
nvm alias default 24.21.0
```
