# golang

Go 공식 배포본(linux/amd64)을 GitHub Release로 제공합니다.
go.dev에서 받은 파일을 수정 없이 올리므로 SHA256이 [go.dev/dl](https://go.dev/dl/)에 게시된 값과 같습니다.

## 설치

[Releases](https://github.com/ms-iipt/golang/releases)에서 받아 `/usr/local/go`에 풀면 설치가 끝납니다.

```sh
VERSION=1.26.8
BASE=https://github.com/ms-iipt/golang/releases/download/go$VERSION
curl -fLO $BASE/go$VERSION.linux-amd64.tar.gz
curl -fLO $BASE/go$VERSION.linux-amd64.tar.gz.sha256
sha256sum -c go$VERSION.linux-amd64.tar.gz.sha256

sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go$VERSION.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin   # 계속 쓰려면 ~/.profile 에 추가
go version                            # go version go1.26.8 linux/amd64
```

`sudo` 권한이 없으면 `/usr/local` 대신 홈 디렉터리 아래(예: `$HOME/.local`)에 풀고 그 아래 `go/bin`을 PATH에 추가합니다.

## 새 버전 릴리스

[release 워크플로](.github/workflows/release.yml)가 다음을 수행합니다.

1. go.dev에서 `go<버전>.linux-amd64.tar.gz`를 내려받아 go.dev에 게시된 SHA256과 대조
2. linux/amd64 러너에서 위 절차대로 설치하고 `go version` 확인 및 테스트 프로그램 실행
3. `go<버전>` 태그로 Release 생성 (tarball + `.sha256`)

실행 방법 (예: 1.26.9):

- Actions 탭 → release → Run workflow → 버전 입력
- `gh workflow run release.yml -f version=1.26.9`
- `git tag go1.26.9 && git push origin go1.26.9`

같은 태그의 Release가 이미 있으면 실패하므로, 다시 만들려면 기존 Release와 태그를 먼저 삭제합니다.

파일만 로컬로 받으려면 `scripts/fetch-go.sh 1.26.8`을 실행합니다. `dist/`에 저장되며 `curl`, `jq`, `sha256sum`이 필요합니다.

## actions/go-versions 패키지를 쓰지 않는 이유

[actions/go-versions](https://github.com/actions/go-versions)의 패키지는 GitHub Actions 러너의 tool cache 전용입니다.
최상위 `go/` 디렉터리 없이 러너용 `setup.sh`가 함께 들어 있고, SHA256도 공식 배포본과 다릅니다.
서버에 풀어서 설치하는 용도에는 공식 tarball을 그대로 쓰는 편이 맞습니다.
