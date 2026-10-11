# CI 파이프라인

PR 과 `dev`·`main` push 를 검증한다. 기준 파일은 `.github/workflows/ci.yml`, `.github/workflows/_changes.yml`, `.github/actions/setup/action.yml` 이다.

## 한눈에 보기

| 항목      | 내용                                                      |
| --------- | --------------------------------------------------------- |
| 필수 체크 | **`ci-ok` 하나** (브랜치 ruleset)                         |
| 검사 범위 | PR 은 영향받은 앱만, `dev`·`main` push 는 전체            |
| 빌드 도구 | pnpm + Turborepo. Turbo 캐시는 GitHub Actions 캐시에 보관 |
| 알림      | `dev`·`main` push 의 CI 가 실패하면 GitHub 이슈 자동 생성 |
| 시크릿    | 사용하지 않음 (`GITHUB_TOKEN` 만 사용)                    |

### 원칙

1. **필수 체크는 하나만**: `ci-ok` 가 모든 job 결과를 모아 판정한다. job 을 추가하거나 건너뛰어도 ruleset 은 그대로다.
2. **PR 은 영향받은 것만, push 는 전체**: PR 은 빠르게, push 는 이전 실패가 가려지지 않게 전부 돌린다.
3. **Fail-closed**: 변경 감지가 실패하거나 모호하면 통과시키지 않고 실패시킨다.
4. **캐시는 최적화일 뿐**: 캐시 복원이 실패해도 CI 는 계속된다.

## 흐름

```
PR ──► ci.yml
        changes (merge-base 기준 영향 판단)
          ├─► workflows-lint   .github 변경 시
          ├─► web              web 영향 시
          └─► server           server 영향 시
        commitlint             항상 (PR 만)
        └─► ci-ok  ◄── 유일한 필수 체크

dev/main push ──► ci.yml (전체 실행) ──► ci-ok ──► 실패 시 alert (이슈 생성)
```

## 검사 목록

| job              | 하는 일                                                                                    | 실행 조건       |
| ---------------- | ------------------------------------------------------------------------------------------ | --------------- |
| `changes`        | 이번 변경이 어떤 앱에 영향을 주는지 판단. 실패하면 곧바로 `ci-ok` 실패                     | 항상            |
| `workflows-lint` | 워크플로·합성 액션 문법 검사 (actionlint)                                                  | `.github/` 변경 |
| `commitlint`     | PR 의 모든 커밋 메시지와 PR 제목 검사. squash 머지 시 PR 제목이 커밋이 된다                | PR              |
| `web`            | `@yaguhae/web` lint · typecheck · test · build                                             | web 영향        |
| `server`         | `@yaguhae/server` lint · typecheck · test · test:e2e · build + **Docker 이미지 빌드 검증** | server 영향     |
| **`ci-ok`**      | 위 결과를 모아 판정                                                                        | 항상            |
| `alert`          | push CI 실패를 이슈로 알림                                                                 | push 실패 시    |

## 영향 범위 규칙 (PR)

`_changes.yml` 이 `turbo query affected` 로 패키지별 영향 여부를 묻는다. Turbo 패키지 그래프를 따르므로 의존하는 패키지가 바뀌면 함께 영향받는다.

| 바뀐 것                                      | 실행되는 앱 검사                                       |
| -------------------------------------------- | ------------------------------------------------------ |
| `apps/web/**`                                | web                                                    |
| `apps/server/**`                             | server                                                 |
| `packages/shared/**`, `packages/*-config/**` | web, server (둘 다 의존)                               |
| 공통 파일 (아래)                             | web, server                                            |
| `.github/**`                                 | + workflows-lint                                       |
| 그 외 (문서 등)                              | 앱 검사 없음. `changes`, `commitlint`, `ci-ok` 만 실행 |

**공통 파일**: 패키지 그래프 밖에 있어서 패키지별로 판단할 수 없으므로, 바뀌면 전체를 실행한다.

```
.github/workflows/**  .github/actions/**  turbo.json  pnpm-workspace.yaml
pnpm-lock.yaml  package.json(루트)  .npmrc  .nvmrc
```

**패키지 이름 가드**: `turbo query affected` 는 없는 패키지 이름에도 오류 없이 "영향 없음"으로 답한다. 이름이 틀리면 그 앱의 CI 가 조용히 건너뛰어지므로, `changes` 는 `turbo ls` 로 `PKG_*` 가 모두 있는지 먼저 확인하고 없으면 실패한다.

판단 결과는 `changes` job 의 **실행 요약(Summary)** 에 표로 나온다. "왜 이 검사가 안 돌았지?" 는 여기서 확인한다.

## `ci-ok` 판정

| 결과                                            | 판정    |
| ----------------------------------------------- | ------- |
| `changes` 성공, 나머지 success 또는 skipped     | ✅ 통과 |
| `changes` 가 성공하지 못함                      | ❌      |
| 하나라도 failure 또는 cancelled (타임아웃 포함) | ❌      |

## 캐시

| 대상              | 방법                                                                                                                              |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| pnpm store        | `actions/setup-node` 의 `cache: pnpm`                                                                                             |
| Turbo 태스크 결과 | `actions/cache` 로 `.turbo/cache` 보관 (job 별 키). PR 에서 저장한 캐시는 그 PR 에서만 보여 `dev`·`main` 캐시를 오염시키지 않는다 |
| Docker 레이어     | `type=gha,scope=server`                                                                                                           |

## 브랜치 ruleset (`dev`, `main`)

- PR 필수 (리뷰 승인 수 0)
- 필수 체크 `ci-ok`, 브랜치가 최신 상태여야 머지 가능
- 강제 push·브랜치 삭제 금지

## 로컬에서 똑같이 돌려보기

```bash
pnpm install --frozen-lockfile

pnpm exec turbo run lint typecheck test build --filter=@yaguhae/web
pnpm exec turbo run lint typecheck test test:e2e build --filter=@yaguhae/server
docker build -f apps/server/Dockerfile .

# 워크플로 lint
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12 -color

# 내 브랜치가 어떤 앱에 영향을 주는지 (1 이면 영향 있음)
TURBO_SCM_BASE=$(git merge-base origin/dev HEAD) \
  pnpm exec turbo query affected --packages @yaguhae/web --exit-code; echo "exit=$?"
```

## 확장할 때

**새 앱 추가**

1. `_changes.yml`: `PKG_<APP>` 환경변수, `APPS`·`PKG`·`RES`, `outputs` 에 추가
2. `ci.yml`: 앱 job 추가 후 **`ci-ok` 의 `needs` 에 추가**

**새 검사 추가** (보안 스캔 등)

1. `ci.yml` 에 job 추가 (`needs: changes`, 필요하면 `if:` 로 범위 지정), 타임아웃 지정
2. `ci-ok` 의 `needs` 에 추가
3. 이 문서 갱신

## 주의

- `ci.yml` 의 `name: CI` 를 바꾸지 않는다. 나중에 배포 워크플로가 이 이름으로 CI 완료를 감지한다.
- `ci-ok` 이름을 바꾸면 ruleset 의 필수 체크도 함께 바꿔야 한다.
- 배포(CD)는 아직 없다. 배포처가 정해지면 `deploy.yml` 과 `_changes.yml` 의 deploy 모드를 추가한다.
