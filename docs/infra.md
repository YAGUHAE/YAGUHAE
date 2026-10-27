# 인프라 설계

MVP 배포·운영 인프라의 구성과 결정 사항을 정리한다. 기준 문서는 [PRD 7장](design/PRD.md)이고, 배포 파이프라인은 [CD](cd.md), CI는 [CI](ci.md)를 본다.

## 1. 구성도

```
                    사용자 (모바일 / 데스크톱 / 카카오톡 인앱 브라우저)
                                      │ HTTPS
                  ┌───────────────────┴───────────────────┐
                  ▼                                       ▼
        app.<도메인> (CNAME)                      api.<도메인> (A → Elastic IP)
                  │                                       │
        ┌─────────▼─────────┐                   ┌─────────▼───────────────┐
        │ Vercel            │   REST (CORS)     │ AWS EC2 (ap-northeast-2)│
        │ Next.js + PWA     │ ────────────────► │ nginx :80/:443          │
        │ apps/web          │  refresh 쿠키     │  └ NestJS blue / green  │
        └───────────────────┘  Domain=.<도메인> │    apps/server          │
                                                └─────────┬───────────────┘
                                                          │ Session pooler :5432 (SSL)
                                                ┌─────────▼───────────────┐
                                                │ Supabase PostgreSQL     │
                                                │ (DB 만 사용, 서울 리전)  │
                                                └─────────────────────────┘

  DNS: Route 53        시크릿: SSM Parameter Store        배포: GitHub Actions (OIDC + SSM)
  에러: Sentry         업타임: UptimeRobot (/health)       알림: 카카오 알림톡 (대행사 미정)
```

## 2. 결정 사항

| 영역            | 결정                                                                                 |
| --------------- | ------------------------------------------------------------------------------------ |
| ORM             | TypeORM + `typeorm-transactional` (PRD 유지)                                         |
| 앱 이름         | `apps/server` 로 통일 (PRD 의 `apps/api` 표기를 수정)                                |
| Cron 중복 실행  | DB advisory lock 으로 한 인스턴스만 실행                                             |
| HTTPS           | EC2 의 nginx + Let's Encrypt (certbot)                                               |
| EC2             | `t4g.small`, 서울 리전, Elastic IP, 접속은 SSM Session Manager 만 (SSH 22 닫음)      |
| 시크릿          | SSM Parameter Store (SecureString). 서버에 `.env` 평문을 두지 않는다                 |
| DB 환경         | prod 만 Supabase, 로컬은 Docker Postgres                                             |
| Supabase 플랜   | 개발 중 Free, 베타 오픈 전 Pro. PITR 은 보류                                         |
| Vercel 플랜     | 베타는 Hobby, 정식 오픈 전 Pro                                                       |
| DNS             | Route 53                                                                             |
| PWA             | 설치 + 오프라인 셸까지. 푸시는 P2-3 으로 미룸                                        |
| 모니터링        | Sentry (web, server) + UptimeRobot. 로그는 Docker 로그 로테이션                      |
| IaC             | MVP 는 콘솔 수동 구성. 재현 절차는 문서로 기록                                       |
| Preview 로그인  | Preview 에서는 로그인 검증을 생략 (쿠키 도메인이 달라 공유 불가)                     |
| 가용성          | PRD 수준 유지: 단일 EC2, 장애 시 수동 재기동 허용                                    |
| 월 예산         | **상한 약 $50 (가정)**. 처음엔 약 $30 이하를 목표로 했으나 Supabase Pro 를 쓰면 초과 |
| 알림톡 발송대행 | **미정**. 사업자 등록·채널 개설 후 7주차 전에 결정                                   |

## 3. 구성 상세

### 3.1 도메인과 DNS

| 레코드         | 대상                                  |
| -------------- | ------------------------------------- |
| `app.<도메인>` | Vercel (CNAME, Vercel 이 안내하는 값) |
| `api.<도메인>` | EC2 Elastic IP (A)                    |

- 두 서브도메인이 같은 상위 도메인이라 refresh 쿠키(`HttpOnly; Secure; SameSite=Lax; Domain=.<도메인>`)를 공유한다.
- 카카오 OAuth Redirect URI 는 `https://api.<도메인>/...` 콜백으로 등록한다.
- CORS 허용 origin 은 `https://app.<도메인>` 하나로 두고, Preview 도메인은 필요할 때만 환경변수로 추가한다.

### 3.2 Web (Vercel, PWA)

- Root Directory `apps/web`, Production 브랜치 `main`, PR 마다 Preview. 설정 절차는 [CD](cd.md#3-vercel).
- PWA 범위: `manifest`(아이콘 192/512, maskable), 서비스워커, 정적 에셋 캐시, 오프라인 폴백 페이지.
  - 서비스워커는 Serwist(`@serwist/next`)를 후보로 한다. 구현 시점에 Next 버전과의 호환을 확인한다.
  - 배포 후 구버전 서비스워커가 남지 않도록 "새 버전이 있어요" 갱신 안내를 둔다.
  - API 응답(예약 상태 등)은 오래된 값이 보이면 안 되므로 캐시하지 않거나 NetworkFirst 로 한다.
- **카카오톡 인앱 브라우저에서는 홈 화면 설치가 되지 않는다.** 알림톡 링크로 들어온 사용자에게는 "기본 브라우저로 열기" 안내를 보여준다.
- 푸시(P2-3)는 MVP 범위가 아니다. iOS 는 홈 화면에 설치한 PWA 에서만 푸시가 동작한다.

### 3.3 Server (EC2)

| 항목     | 값                                                                                                             |
| -------- | -------------------------------------------------------------------------------------------------------------- |
| 인스턴스 | `t4g.small` (ARM, 2 vCPU / 2GB), Amazon Linux 2023                                                             |
| 네트워크 | 보안그룹 인바운드 80, 443 만. 22 는 닫는다                                                                     |
| 접속     | SSM Session Manager. 인스턴스 프로파일에 `AmazonSSMManagedInstanceCore` + 시크릿 읽기 권한                     |
| 런타임   | Docker Compose: nginx + NestJS (blue / green). 배포 방식은 [CD](cd.md#ec2-blue-green-appsserverdeploydeploysh) |
| 이미지   | GHCR `ghcr.io/yaguhae/yaguhae-server:sha-<커밋>`                                                               |

- Blue-Green 중에는 NestJS 컨테이너가 2개 뜬다. 2GB 에서 부족해 보이면 스왑을 추가한다.
- **아키텍처 불일치**: `deploy.yml` 의 이미지 빌드는 `platform` 을 지정하지 않아 `ubuntu-latest`(x86)에서 `linux/amd64` 로 만들어진다. ARM 인스턴스(`t4g`)에서는 실행되지 않는다. 첫 배포 전에 둘 중 하나로 맞춘다.
  - `docker/build-push-action` 에 `platforms: linux/arm64` 를 지정하고 QEMU 를 설정하거나 ARM 러너를 쓴다. 에뮬레이션 빌드는 느리다.
  - 또는 x86 인스턴스(`t3.small`)로 바꾼다. 비용은 약 $3~4 더 든다.
- 로그는 Docker `json-file` 드라이버의 `max-size`, `max-file` 로 로테이션한다.

### 3.4 HTTPS

- 현재 nginx 는 80 만 열려 있다. 443 과 인증서 볼륨(`/etc/letsencrypt`)을 추가한다.
- 인증서 발급·갱신은 certbot 으로 하고, 갱신 후 nginx reload 를 자동화한다.
- Route 53 의 `api.<도메인>` 레코드가 먼저 EC2 를 가리켜야 발급할 수 있다.

### 3.5 DB (Supabase)

- 서울 리전(ap-northeast-2). **리전은 만든 뒤 바꿀 수 없다.**
- 접속은 **Session pooler(5432)**. EC2 는 IPv4 라 direct connection(IPv6)을 쓸 수 없고, 장기 실행 서버에서는 Transaction pooler(6543)를 쓰지 않는다.
- Auth, RLS, Realtime, pg_cron 은 쓰지 않는다. 다만 Supabase 가 Data API 를 노출하므로 `public` 테이블에는 RLS 를 켜고 정책을 두지 않아(= 전부 차단) 외부에서 직접 접근하지 못하게 한다.
- Blue-Green 중에는 두 컨테이너가 같은 DB 에 접속한다. TypeORM 커넥션 풀 크기를 작게(예: 컨테이너당 10 이하) 잡고 pooler 연결 한도를 넘지 않는지 확인한다.
- 마이그레이션은 앱 교체 전에 같은 접속 문자열로 실행한다. 두 색상이 잠시 같은 DB 를 쓰므로 **하위 호환 마이그레이션만** 허용한다.
- 백업: 개발 중 Free 는 자동 백업이 없다. 실사용자 데이터가 들어오기 전(베타 오픈 전)에 Pro 로 올리고 일일 백업을 확보한다.
- Free 는 일정 기간 비활성이면 프로젝트가 일시정지된다. 개발 중에는 UptimeRobot 의 `/health` 호출이 DB 를 건드리게 하거나, 정지되면 대시보드에서 복구한다.
- 로컬은 `docker compose` 의 Postgres. `synchronize: false` 로 마이그레이션만 쓴다.

### 3.6 Cron 중복 실행 방지

PRD 는 `@nestjs/schedule` 과 "API 단일 인스턴스"를 전제로 하지만, Blue-Green 배포 중에는 두 컨테이너가 잠시 함께 떠 있다.

- 각 Cron 작업은 시작할 때 `pg_try_advisory_xact_lock(<작업별 고정 키>)` 를 **트랜잭션 안에서** 시도하고, 실패하면 그 회차를 건너뛴다.
- 세션 단위 락(`pg_try_advisory_lock`)은 풀링 환경에서 락을 잡은 연결과 해제하는 연결이 달라질 수 있어 쓰지 않는다. 트랜잭션 단위 락은 커밋과 함께 자동으로 풀린다.
- 만료 쿼리는 PRD 7.3 의 조건부 업데이트라 중복 실행돼도 결과는 같지만, **알림톡 발송은 중복 시 사용자에게 두 번 간다.** 락이 필요한 이유다.
- 이 방식은 나중에 인스턴스를 늘려도 그대로 동작한다.

### 3.7 시크릿과 환경변수

| 위치                | 내용                                                              |
| ------------------- | ----------------------------------------------------------------- |
| SSM Parameter Store | `/yaguhae/prod/*` : DB URL, JWT 시크릿, 카카오 키, Sentry DSN 등  |
| GitHub              | Secrets 를 쓰지 않는다. AWS OIDC 로 역할을 가장한다 ([CD](cd.md)) |
| Vercel Environment  | web 에서 쓰는 공개 값(API 주소 등). 비밀값은 두지 않는다          |

- 지금 `deploy.sh` 는 서버의 `/opt/yaguhae/.env` 를 읽는다. SSM 에서 값을 읽어 컨테이너에 주입하도록 `deploy.sh` 를 바꾼다. (후속 이슈)
- Standard 티어 SecureString 은 추가 요금이 없다.

### 3.8 모니터링과 로깅

| 목적      | 도구                   | 비고                                                           |
| --------- | ---------------------- | -------------------------------------------------------------- |
| 에러 추적 | Sentry                 | web, server 각각 프로젝트. 무료 플랜으로 시작                  |
| 업타임    | UptimeRobot            | `https://api.<도메인>/health`, `https://app.<도메인>` 5분 간격 |
| 로그      | Docker 로그 + 로테이션 | 문제 조사 시 SSM 으로 접속해 확인                              |

## 4. 비용 (월 추정)

| 항목                               | 개발 중       | 베타 오픈 후  | 정식 오픈 후  |
| ---------------------------------- | ------------- | ------------- | ------------- |
| EC2 `t4g.small` + EBS + Elastic IP | 약 $15~18     | 약 $15~18     | 약 $15~18     |
| Supabase                           | $0            | $25 (Pro)     | $25 (Pro)     |
| Route 53                           | 약 $1         | 약 $1         | 약 $1         |
| Vercel                             | $0            | $0 (Hobby)    | $20 (Pro)     |
| Sentry, UptimeRobot, SSM           | $0            | $0            | $0            |
| **합계**                           | **약 $16~19** | **약 $41~44** | **약 $61~64** |

- 도메인 등록비(연 단위)와 데이터 전송량 초과분은 제외했다. 숫자는 대략치이므로 오픈 전에 실제 청구서로 다시 확인한다.
- 예산 상한을 $50 으로 가정하면 베타 오픈까지는 안에 들어오고, **정식 오픈 후 Vercel Pro 를 쓰면 초과**한다. 그 시점에 상한을 다시 정한다.
- Vercel Hobby 는 비상업 용도 제한이 있다. 수익화 전까지만 쓰고, 정식 오픈 전에 약관을 다시 확인해 Pro 로 전환한다.

## 5. 보안

- API 는 HTTPS 만 받는다. nginx 에서 80 → 443 리다이렉트(인증서 갱신용 경로 제외).
- EC2 는 SSH 를 열지 않고, 배포용 IAM Role 은 지정한 인스턴스의 `AWS-RunShellScript` 만 실행할 수 있다.
- 계좌번호·휴대폰 번호는 응답 DTO 에서 필요한 화면에만 노출한다 (PRD 5장).
- `helmet`, rate limit(`@nestjs/throttler`), 입력 검증을 서버에 적용한다. 로그인·예약 엔드포인트는 더 엄격히 제한한다.
- 개인정보 처리방침·이용약관은 베타 오픈 전에 필요하다 (PRD 5장).

## 6. 운영

| 상황                | 대응                                                                                   |
| ------------------- | -------------------------------------------------------------------------------------- |
| 서버 배포 실패      | `deploy.sh` 가 이전 색상으로 롤백하고 이슈를 만든다. `deployed/server` 태그는 그대로다 |
| 프로세스 다운       | `restart: unless-stopped` 로 자동 재시작                                               |
| 인스턴스 장애       | UptimeRobot 알림 → SSM 으로 접속해 수동 복구 (PRD 가용성 수준)                         |
| 잘못된 마이그레이션 | 하위 호환 변경만 허용하므로 이전 이미지로 롤백한 뒤 마이그레이션을 별도로 되돌린다     |
| DB 복구             | Pro 의 일일 백업에서 복원. 오픈 전에 복원 절차를 한 번 시험한다                        |

## 7. 남은 일

구현은 아래 이슈로 나눠 진행한다. 이슈는 만들어지는 대로 번호를 채운다.

- [ ] 도메인 구매, Route 53 호스트 존과 레코드
- [ ] nginx HTTPS(443) 와 certbot 자동 갱신
- [ ] `deploy.sh` 가 SSM Parameter Store 에서 시크릿을 읽도록 변경
- [ ] ARM 인스턴스에 맞는 Docker 이미지 빌드(`linux/arm64`) 또는 인스턴스 아키텍처 재결정
- [ ] TypeORM 설정, `typeorm-transactional`, 마이그레이션과 배포 연동 (`deploy.sh` TODO 위치)
- [ ] Cron 작업의 advisory lock 래퍼
- [ ] 로컬 개발용 Postgres `docker-compose.yml`
- [ ] Sentry, UptimeRobot 연동
- [ ] PWA (manifest, 서비스워커, 오프라인 폴백, 카카오 인앱 안내)
- [ ] 알림톡 발송 대행사 선정 (사업자 등록, 비즈니스 채널 개설 선행)
- [ ] Supabase Pro 전환과 백업 복원 시험 (베타 오픈 전)
