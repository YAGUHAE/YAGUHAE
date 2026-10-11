#!/usr/bin/env bash
# EC2 에서 Blue-Green 배포를 한다. GitHub Actions 가 SSM Run Command 로 실행한다.
#
#   bash deploy.sh <이미지>     예) bash deploy.sh ghcr.io/yaguhae/yaguhae-server:sha-abc1234
#
# 1. 쉬고 있는 색상(Green)으로 새 이미지를 띄운다. 기존 색상(Blue)은 계속 서비스한다.
# 2. Green 컨테이너 헬스체크가 통과하면 nginx upstream 을 Green 으로 바꾸고 reload 한다.
# 3. nginx 를 거쳐 /health 를 다시 확인한다.
# 4. 성공하면 Blue 를 멈춘다. 중간에 실패하면 Blue 로 되돌리고 Green 을 정리한다.
# -E: 함수 안에서 난 오류에도 ERR trap(롤백)이 동작하게 한다.
set -Eeuo pipefail

IMAGE="${1:?사용법: deploy.sh <이미지>}"
cd "$(dirname "$0")"

COMPOSE=(docker compose --env-file images.env -f compose.yml)
HEALTH_TIMEOUT=90 # 초

log() { echo "[deploy] $*"; }

touch images.env
active=$(cat .active 2>/dev/null || echo none)
case "$active" in
  blue) next=green ;;
  *) next=blue ;; # 첫 배포(none)도 blue 부터
esac
log "활성: ${active} → 새로 띄울 색상: ${next}"

set_image() { # $1=색상 $2=이미지 — images.env 의 해당 줄만 바꾼다.
  local key
  key="SERVER_IMAGE_$(tr '[:lower:]' '[:upper:]' <<<"$1")"
  grep -v "^${key}=" images.env >images.env.tmp || true
  echo "${key}=$2" >>images.env.tmp
  mv images.env.tmp images.env
}

write_upstream() { # $1=색상
  cat >nginx/conf.d/upstream.conf <<EOF
upstream server {
    server server-$1:4000;
    keepalive 16;
}
EOF
}

reload_nginx() {
  if [ -z "$("${COMPOSE[@]}" ps -q --status running nginx)" ]; then
    "${COMPOSE[@]}" up -d --no-deps nginx
  else
    "${COMPOSE[@]}" exec -T nginx nginx -t
    "${COMPOSE[@]}" exec -T nginx nginx -s reload
  fi
}

wait_healthy() { # $1=컨테이너 이름
  local status elapsed=0
  while [ "$elapsed" -lt "$HEALTH_TIMEOUT" ]; do
    status=$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null || echo missing)
    case "$status" in
      healthy) return 0 ;;
      unhealthy | missing) break ;;
    esac
    sleep 3
    elapsed=$((elapsed + 3))
  done
  log "헬스체크 실패: $1 (상태: ${status})"
  docker logs --tail 100 "$1" || true
  return 1
}

switched=false
rollback() {
  log "실패 → 롤백"
  if [ "$switched" = true ] && [ "$active" != none ]; then
    write_upstream "$active"
    reload_nginx || log "nginx 되돌리기 실패: 수동 확인 필요"
  fi
  "${COMPOSE[@]}" rm -sf "server-${next}" || true
}
trap rollback ERR

# 1. Green 기동
set_image "$next" "$IMAGE"
"${COMPOSE[@]}" pull "server-${next}"
# TODO: DB 마이그레이션이 생기면 여기서 실행한다. Blue 와 같은 DB 를 함께 쓰므로 하위 호환 변경만 허용한다.
"${COMPOSE[@]}" up -d --no-deps --force-recreate "server-${next}"
wait_healthy "yaguhae-server-${next}"

# 2. 트래픽 전환
write_upstream "$next"
switched=true
reload_nginx

# 3. nginx 를 거쳐 다시 확인
ok=false
for _ in $(seq 1 10); do
  if curl -fsS http://127.0.0.1/health >/dev/null; then ok=true; break; fi
  sleep 2
done
if [ "$ok" != true ]; then
  log "nginx 경유 헬스체크 실패"
  false # ERR trap → 롤백
fi

# 4. 정리
trap - ERR
echo "$next" >.active
if [ "$active" != none ]; then
  "${COMPOSE[@]}" stop "server-${active}"
fi
docker image prune -f >/dev/null
log "배포 완료: ${next} (${IMAGE})"
