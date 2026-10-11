# CD 파이프라인

| 앱     | 배포처  | 방식                                                                       |
| ------ | ------- | -------------------------------------------------------------------------- |
| server | AWS EC2 | `.github/workflows/deploy.yml` — GHCR 이미지 → AWS OIDC + SSM → Blue-Green |
| web    | Vercel  | Vercel Git 연동 — Deployment Checks 로 `ci-ok` 통과 후에만 production 반영 |

인증은 전부 OIDC 다. **GitHub Secrets 를 쓰지 않는다.**

## 흐름

```
작업 브랜치 ──PR──► dev ──PR(merge commit)──► main
                                             │
                                             ├─► ci.yml (전체 실행) ── 실패 ─► 이슈, 배포 안 함
                                             │      └─ 성공 ─► deploy.yml (workflow_run)
                                             │                  gate: 배포 스위치 ON? 성공한 push CI? 최신 main?
                                             │                  changes: deployed/server 태그 이후 server 영향?
                                             │                  server: 이미지 push → SSM → deploy.sh (Blue-Green)
                                             │                    ├─ 성공: deployed/server 태그 이동
                                             │                    └─ 실패: 롤백(EC2) + 이슈, 태그 유지
                                             │
                                             └─► Vercel: production 빌드 → ci-ok 통과 후 반영

dev, 작업 브랜치 ──► Vercel Preview 배포
```

### 원칙

1. **CI 가 성공한 main 커밋만 배포**한다. 배포는 CI 결과를 보고 따라간다 (`workflow_run`).
2. **누락보다 중복 배포**: 실패한 배포는 `deployed/server` 태그를 옮기지 않으므로 다음 배포에서 다시 대상이 된다.
3. **설정 전에는 건너뛴다**: repo variable `SERVER_DEPLOY_ENABLED=true` 가 아니면 배포 job 은 실패가 아니라 건너뛴다.

## `dev` → `main` 배포 PR

- **"Create a merge commit"** 으로 머지한다. squash 하면 `main` 과 `dev` 의 히스토리가 갈라져 다음 배포 PR 에서 같은 변경이 다시 나온다.
- PR 대상(base)이 기본값 `dev` 로 잡히므로 **`main` 으로 바꿔야** 한다.
- PR 제목도 commitlint 대상이다. 예) `chore(repo): 1차 배포`

## server 배포 (`deploy.yml`)

### `gate`

| 조건                                                 | 불충족 시                                          |
| ---------------------------------------------------- | -------------------------------------------------- |
| `vars.SERVER_DEPLOY_ENABLED == 'true'`               | 건너뜀                                             |
| (수동) 실행한 ref 가 `main`                          | 건너뜀                                             |
| (자동) CI 결론이 `success`, `push` 이벤트, 같은 레포 | 건너뜀                                             |
| 배포할 커밋이 현재 `main` 최신 커밋                  | 건너뜀 (더 새 커밋의 CI 가 태그 기준으로 따라잡음) |

### `changes` (deploy 모드)

| 조건                                                                          | 결과       |
| ----------------------------------------------------------------------------- | ---------- |
| `deployed/server` 태그가 없거나 현재 커밋의 조상이 아님 (첫 배포, force push) | 배포       |
| 태그 이후 공통 파일 변경 (lockfile, turbo.json, 워크플로 등)                  | 배포       |
| 태그 이후 server 또는 server 가 의존하는 패키지(shared 등) 변경               | 배포       |
| 그 외 (web 만, 문서만)                                                        | 배포 안 함 |

수동 실행(`workflow_dispatch`)은 변경 여부와 관계없이 배포한다.

### `server` job (`production` Environment)

| #   | 단계                                                                    | 실패 시                                    |
| --- | ----------------------------------------------------------------------- | ------------------------------------------ |
| 1   | 필수 변수 확인 (`AWS_REGION`, `AWS_DEPLOY_ROLE_ARN`, `EC2_INSTANCE_ID`) | job 실패                                   |
| 2   | 이미지 빌드 & push → `ghcr.io/yaguhae/yaguhae-server:sha-<커밋>`        | job 실패, 서비스 영향 없음                 |
| 3   | AWS OIDC 로 IAM Role 가장                                               | job 실패                                   |
| 4   | SSM Run Command 로 EC2 에서 배포 파일을 받아 `deploy.sh` 실행           | `deploy.sh` 가 롤백, job 실패              |
| 5   | `deployed/server` 태그 이동                                             | 다음 배포에서 재배포 (중복일 뿐 누락 아님) |

### EC2 Blue-Green (`apps/server/deploy/deploy.sh`)

```
/opt/yaguhae
├─ compose.yml, deploy.sh, nginx/conf.d/default.conf   ← 배포마다 해당 커밋 버전으로 받아옴
├─ nginx/conf.d/upstream.conf                          ← 활성 색상 (deploy.sh 가 생성)
├─ images.env, .active                                 ← 색상별 이미지, 활성 색상 (deploy.sh 가 관리)
└─ .env                                                ← 앱 런타임 환경변수 (사람이 직접 작성)
```

1. 쉬고 있는 색상으로 새 이미지를 띄운다. 기존 색상은 계속 서비스한다.
2. 새 컨테이너 헬스체크(`/health`)가 통과하면 nginx upstream 을 바꾸고 reload 한다.
3. nginx 를 거쳐 `/health` 를 다시 확인한다.
4. 성공하면 이전 색상을 멈춘다. 중간에 실패하면 이전 색상으로 되돌리고 새 컨테이너를 지운다.

로컬 Docker 로 확인한 것: 첫 배포(blue), 두 번째 배포(green 전환, 배포 중 요청 40개 모두 200), 헬스체크 실패 이미지(롤백, 기존 색상 유지, 종료 코드 1).

> DB 마이그레이션이 생기면 `deploy.sh` 의 TODO 위치(새 컨테이너 기동 전)에서 실행한다. 두 색상이 같은 DB 를 잠시 함께 쓰므로 **하위 호환 마이그레이션만** 허용한다.

## web 배포 (Vercel)

Vercel 이 레포를 직접 보고 빌드·배포한다. 워크플로 파일은 없다.

| 브랜치                         | Vercel                                                                        |
| ------------------------------ | ----------------------------------------------------------------------------- |
| `main`                         | Production. Deployment Checks 의 `ci-ok` 가 통과해야 production 도메인에 반영 |
| 그 외 (`dev`, 작업 브랜치, PR) | Preview                                                                       |

## 초기 설정 체크리스트

### 1. AWS

- [ ] **GitHub OIDC Provider** 추가 (IAM → Identity providers)
  - Provider URL: `https://token.actions.githubusercontent.com`
  - Audience: `sts.amazonaws.com`
- [ ] **배포용 IAM Role** (`yaguhae-github-deploy`) 생성
  - 신뢰 정책: `production` Environment 의 job 만 가장할 수 있다.

    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
          },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": {
            "StringEquals": {
              "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
              "token.actions.githubusercontent.com:sub": "repo:YAGUHAE/YAGUHAE:environment:production"
            }
          }
        }
      ]
    }
    ```

  - 권한 정책: 지정한 인스턴스에 `AWS-RunShellScript` 만 실행할 수 있다.

    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "ssm:SendCommand",
          "Resource": [
            "arn:aws:ssm:<REGION>::document/AWS-RunShellScript",
            "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:instance/<INSTANCE_ID>"
          ]
        },
        {
          "Effect": "Allow",
          "Action": "ssm:GetCommandInvocation",
          "Resource": "*"
        }
      ]
    }
    ```

- [ ] **EC2 인스턴스**
  - AMI: Amazon Linux 2023 권장 (SSM Agent 기본 설치)
  - 인스턴스 프로파일(IAM Role)에 `AmazonSSMManagedInstanceCore` 정책 연결
  - 보안그룹 인바운드: `80` (HTTPS 적용 시 `443`). **SSH(22)는 열지 않아도 된다** (SSM Session Manager 로 접속)
  - 아웃바운드: 인터넷 (GHCR, raw.githubusercontent.com 접근)
  - Docker + Compose 플러그인 설치

    ```bash
    sudo dnf install -y docker
    sudo systemctl enable --now docker
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    sudo curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    docker compose version
    ```

  - `/opt/yaguhae/.env` 작성 (앱 런타임 환경변수. 지금은 없어도 된다)
- [ ] Systems Manager → Fleet Manager 에서 인스턴스가 **Online** 으로 보이는지 확인

### 2. GitHub

- [ ] **Environment `production`**: Settings → Environments
  - Deployment branches: `dev`, `main`
    - `workflow_run` 으로 실행된 job 은 **기본 브랜치(`dev`)** 의 ref 로 돌기 때문에 `dev` 도 허용해야 한다. 수동 실행은 `gate` 가 `main` 만 허용한다.
- [ ] **Repository variables**: Settings → Secrets and variables → Actions → Variables

  | 이름                    | 값                         |
  | ----------------------- | -------------------------- |
  | `AWS_REGION`            | 예) `ap-northeast-2`       |
  | `AWS_DEPLOY_ROLE_ARN`   | 위에서 만든 IAM Role ARN   |
  | `EC2_INSTANCE_ID`       | 예) `i-0123456789abcdef0`  |
  | `SERVER_DEPLOY_ENABLED` | `true` (**마지막에** 설정) |

- [ ] **GHCR 패키지 public 전환**: 첫 배포가 이미지를 push 하면 `yaguhae-server` 패키지가 생긴다. 처음에는 private 이라 EC2 의 pull 이 실패한다.
  1. Actions → Deploy → Run workflow (`main`) 로 첫 배포 실행 → pull 단계에서 실패 (정상)
  2. Organization → Packages → `yaguhae-server` → Package settings → Change visibility → **Public**
  3. 다시 Run workflow

### 3. Vercel

- [ ] Vercel 에서 **Add New → Project** → `YAGUHAE/YAGUHAE` import
  - **Root Directory**: `apps/web`
  - Framework Preset: Next.js (자동 인식)
  - Install / Build Command: 기본값 (pnpm workspace 를 자동 인식해 레포 루트에서 설치한다)
- [ ] Settings → General → **Node.js Version**: `24.x`
- [ ] Settings → Git → **Production Branch**: `main`
- [ ] Settings → **Deployment Checks** → GitHub 체크 **`ci-ok`** 추가
- [ ] (권장) 모노레포에서 `apps/web` 과 의존 패키지가 바뀌지 않은 커밋은 빌드를 건너뛰도록 설정 (Vercel 의 영향 없는 프로젝트 건너뛰기 옵션)
- [ ] 환경변수는 필요할 때 Settings → Environment Variables 에 추가 (예: server API 주소)

### 4. 첫 배포

- [ ] `SERVER_DEPLOY_ENABLED=true` 설정
- [ ] Actions → Deploy → **Run workflow** (`main`) → GHCR public 전환 (위 2번) → 다시 실행
- [ ] EC2 퍼블릭 IP 로 `curl http://<IP>/health` → `{"status":"ok"}`
- [ ] 이후에는 `dev` → `main` 머지만 하면 자동 배포된다.

## 운영

| 상황                           | 할 일                                                                                                              |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| 배포가 안 돌았다               | Deploy 실행의 `gate` notice 확인 (스위치 OFF, CI 실패, 최신 커밋 아님 등)                                          |
| server 가 배포 대상이 아니었다 | `changes` job Summary 확인 (태그 이후 server 영향 없음)                                                            |
| 배포 실패                      | 자동 생성된 이슈 → 실행 로그의 SSM 출력 확인. EC2 는 이전 색상으로 서비스 중. 원인 수정 후 머지하거나 Run workflow |
| 배포 후 문제 발견              | 문제 커밋을 revert PR 로 되돌린다 (자동 롤백은 전환 단계까지만)                                                    |
| EC2 접속                       | Systems Manager → Session Manager → Start session                                                                  |
| 수동 전체 재배포               | Actions → Deploy → Run workflow (`main`)                                                                           |

## 아직 없는 것 (필요할 때 추가)

- HTTPS: 도메인 연결 후 certbot(nginx) 또는 ALB + ACM
- DB 와 마이그레이션 단계
- 스테이징 환경 (`dev` 배포)
- 배포 실패 알림 채널 (지금은 GitHub 이슈만)
