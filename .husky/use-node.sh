# 훅을 .nvmrc 의 Node 버전으로 실행한다.
# 터미널 기본 Node 나 GUI Git 클라이언트의 Node 가 달라도 버전이 맞춰진다.
# nvm 이 없으면 아무것도 하지 않는다.
if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
  . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  if ! nvm use --silent >/dev/null 2>&1; then
    echo "❌ .nvmrc 의 Node $(cat .nvmrc) 가 설치되어 있지 않습니다. 'nvm install' 을 실행해주세요."
    exit 1
  fi
fi
