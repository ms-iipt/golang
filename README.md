# golang

Go 공식 배포본(linux/amd64)을 버전별 GitHub Release(`go<버전>` 태그)로 제공합니다. 여러 버전을 함께 둘 수 있습니다.
go.dev에서 받은 파일을 수정 없이 올리므로 SHA256이 [go.dev/dl](https://go.dev/dl/)에 게시된 값과 같습니다.
각 Release에는 golang.org/x 모듈을 최신으로 올린 비공식 빌드([xupdate](#golangorgx-최신화-빌드-xupdate))도 함께 올라갑니다.

## 설치

[Releases](https://github.com/ms-iipt/golang/releases)에서 받아 `/usr/local/go`에 풀면 설치가 끝납니다.

```sh
VERSION=1.27.3
FILE=go$VERSION.linux-amd64.tar.gz   # xupdate 빌드는 go$VERSION.linux-amd64.xupdate.tar.gz
BASE=https://github.com/ms-iipt/golang/releases/download/go$VERSION
curl -fLO $BASE/$FILE
curl -fLO $BASE/$FILE.sha256
sha256sum -c $FILE.sha256

sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf $FILE
export PATH=$PATH:/usr/local/go/bin   # 계속 쓰려면 ~/.profile 에 추가
go version                            # go version go1.27.3 linux/amd64
```

`sudo` 권한이 없으면 `/usr/local` 대신 홈 디렉터리 아래(예: `$HOME/.local`)에 풀고 그 아래 `go/bin`을 PATH에 추가합니다.

## 새 버전 릴리스

[release 워크플로](.github/workflows/release.yml)가 입력한 버전마다 병렬로 다음을 수행합니다.

1. go.dev에서 `go<버전>.linux-amd64.tar.gz`를 내려받아 go.dev에 게시된 SHA256과 대조
2. linux/amd64 러너에서 위 절차대로 설치하고 `go version` 확인 및 테스트 프로그램 실행
3. `go<버전>` 태그로 Release 생성 (tarball + `.sha256`)
4. 이어서 xupdate 워크플로로 최신화 빌드를 만들어 같은 Release와 `archives/`에 추가

실행 방법 (여러 버전은 공백이나 쉼표로 구분):

- Actions 탭 → release → Run workflow → 버전 입력 (`xupdate`를 끄면 공식 파일만)
- `gh workflow run release.yml -f versions="1.26.10 1.27.3"`
- `git tag go1.27.3 && git push origin go1.27.3` (버전 하나)

이미 있는 버전의 공식 Release는 그대로 두고 건너뜁니다.
"Latest" 표시는 가장 높은 버전에만 붙으므로, 예전 계열(예: 1.26.x)을 나중에 올려도 옮겨 가지 않습니다.

파일만 로컬로 받으려면 `scripts/fetch-go.sh 1.27.3`을 실행합니다. `dist/`에 저장되며 `curl`, `jq`, `sha256sum`이 필요합니다.

## golang.org/x 최신화 빌드 (xupdate)

Release마다 공식 파일 외에 `go<버전>.linux-amd64.xupdate.tar.gz`도 올라갑니다.
공식 소스에서 표준 라이브러리(std)와 툴체인(cmd)에 포함된 golang.org/x/net, x/text, x/sys를 최신으로 올려 다시 빌드한 **비공식** 배포본입니다.
`go version`은 공식과 같고, 설치도 위와 같은 방법으로 파일 이름만 바꾸면 됩니다. 바뀐 모듈 버전은 릴리스 노트의 표에 있습니다.

같은 파일(`.sha256` 포함)이 저장소의 [archives/](archives/)에도 버전별로 있어서, Release 다운로드를 쓸 수 없으면 `git clone`으로 받거나 다음처럼 받을 수 있습니다.

```sh
curl -fLO https://github.com/ms-iipt/golang/raw/main/archives/go1.27.3.linux-amd64.xupdate.tar.gz
```

[xupdate 워크플로](.github/workflows/xupdate.yml)가 [build-xupdate.sh](scripts/build-xupdate.sh)로 Go 저장소의 vendoring 절차(`src/README.vendor`)를 그대로 수행합니다.

1. go.dev 공식 소스를 받아 SHA256을 대조하고 호스트용으로 빌드
2. std, cmd 모듈에서 `go get <모듈>@latest` → `go mod tidy` → `go mod vendor`
3. 코드 생성용 보조 모듈(`_asm` 등)의 golang.org/x 의존성도 최신으로 (빌드에는 쓰이지 않지만 go.mod를 읽는 스캐너가 검사함)
4. x/net에서 생성되는 net/http 번들 코드와 syscall 생성 코드를 다시 생성
5. 공식 배포본과 같은 `make.bash -distpack`으로 패키징하고, 결과물을 풀어 `go test -short std cmd/...`
6. Release에 파일을 추가하고 릴리스 노트의 버전 표를 갱신, 모든 버전을 모아 `archives/`에 한 번에 커밋 (내용이 같으면 생략)

release 워크플로가 끝에 자동으로 실행합니다.
이미 있는 Release를 그 시점의 최신 모듈로 다시 만들려면 Actions 탭 → xupdate → Run workflow, 또는 `gh workflow run xupdate.yml -f versions="1.26.10 1.27.3"`로 직접 실행합니다.
로컬 빌드는 `GOOS=linux GOARCH=amd64 scripts/build-xupdate.sh 1.27.3`입니다 (macOS에서 교차 빌드 가능, `jq`·`perl` 필요).

알아둘 점:

- Go 모듈 버전 선택(MVS) 때문에 세 모듈 외에도 함께 올라가는 모듈이 있습니다. 예를 들어 x/net은 std의 x/crypto를, x/text는 cmd의 x/mod·x/sync를 함께 올립니다.
- x/text·x/mod는 자기 테스트와 코드 생성기용으로 더 높은 x/tools를 요구하지만(go.mod의 `tagx:ignore`), x/tools는 `go vet`·`go fix`·`go test`가 쓰는 분석기 자체입니다. 그래서 cmd에서는 `replace`로 공식 버전에 고정해, 분석 결과가 공식 배포본과 같게 둡니다. (고정하지 않으면 Go 1.27에서는 vet에 `scannererr`·`sqlrowserr`가 추가되고 printf가 `%d`에 포인터를 넘기는 코드를 새로 잡아, `go test`가 공식과 다르게 실패할 수 있습니다.)
- 보조 모듈 중 vendor 디렉터리가 있는 것(`cmd/compile/internal/ssa/_gen`)은 생성 결과를 테스트로 검증하므로 그대로 둡니다.
- 최신 모듈을 이전 Go 버전에 맞추느라 버전별로 조정하는 부분이 있습니다. 스크립트는 해당하는 경우에만 적용하고 결과를 검증합니다.
  - Go 1.26: 최신 x/net의 http2가 `x/net/internal/httpsfv`를 쓰므로 Go 1.27과 같은 방식으로 `net/http/internal/httpsfv`에 번들하고, net/http 번들 설정과 의존성 규칙(`go/build/deps_test.go`)을 맞춥니다.
  - Go 1.26: 최신 모듈들이 `go 1.26.0`을 요구해 `go mod tidy`가 go 줄을 `go 1.26.0`으로 바꾸지만, cmd/dist는 `go 1.26` 형식이어야 빌드하므로 vendoring 후 원래 값으로 되돌립니다. 언어 버전은 둘 다 go1.26입니다.
  - Go 1.27: net/http 테스트가 쓰던 `golang.org/x/net/http3`가 x/net v0.60.0에서 삭제되었습니다 (HTTP/3는 Go 1.28에서 std로 이동). Go 1.27은 HTTP/3 테스트 모드를 이미 건너뛰므로, 테스트의 import를 빼고 등록 함수를 빈 함수로 둡니다.

## actions/go-versions 패키지를 쓰지 않는 이유

[actions/go-versions](https://github.com/actions/go-versions)의 패키지는 GitHub Actions 러너의 tool cache 전용입니다.
최상위 `go/` 디렉터리 없이 러너용 `setup.sh`가 함께 들어 있고, SHA256도 공식 배포본과 다릅니다.
서버에 풀어서 설치하는 용도에는 공식 tarball을 그대로 쓰는 편이 맞습니다.
