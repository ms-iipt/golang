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

## golang.org/x 최신화 빌드 (xupdate)

Release에는 공식 파일 외에 `go<버전>.linux-amd64.xupdate.tar.gz`도 올라갑니다.
공식 소스에서 표준 라이브러리(std)와 툴체인(cmd)에 포함된 golang.org/x/net, x/text, x/sys를 최신으로 올려 다시 빌드한 **비공식** 배포본입니다.
`go version`은 공식과 같고, 설치도 위와 같은 방법으로 파일 이름만 바꾸면 됩니다. 바뀐 모듈 버전은 릴리스 노트의 표에 있습니다.

같은 파일(`.sha256` 포함)이 저장소의 [archives/](archives/)에도 있어서, Release 다운로드를 쓸 수 없으면 `git clone`으로 받거나 다음처럼 받을 수 있습니다.

```sh
curl -fLO https://github.com/ms-iipt/golang/raw/main/archives/go1.26.8.linux-amd64.xupdate.tar.gz
```

[xupdate 워크플로](.github/workflows/xupdate.yml)가 [build-xupdate.sh](scripts/build-xupdate.sh)로 Go 저장소의 vendoring 절차(`src/README.vendor`)를 그대로 수행합니다.

1. go.dev 공식 소스를 받아 SHA256을 대조하고 호스트용으로 빌드
2. std, cmd 모듈에서 `go get <모듈>@latest` → `go mod tidy` → `go mod vendor`
3. x/net에서 생성되는 net/http 번들(h2_bundle.go 등)과 syscall 생성 코드를 다시 생성
4. 공식 배포본과 같은 `make.bash -distpack`으로 패키징하고, 결과물을 풀어 `go test -short std cmd/...`
5. Release에 파일을 추가하고 릴리스 노트의 버전 표를 갱신, 저장소 `archives/`에 커밋 (내용이 같으면 생략)

실행: Actions 탭 → xupdate → Run workflow, 또는 `gh workflow run xupdate.yml -f version=1.26.8`.
다시 실행하면 그 시점의 최신 버전으로 빌드해 파일을 교체합니다.
로컬 빌드는 `GOOS=linux GOARCH=amd64 scripts/build-xupdate.sh 1.26.8`입니다 (macOS에서 교차 빌드 가능, `jq`·`perl` 필요).

알아둘 점:

- Go 모듈 버전 선택(MVS) 때문에 세 모듈 외에도 함께 올라가는 모듈이 있습니다. 예를 들어 x/net은 std의 x/crypto를, x/text는 cmd의 x/tools·x/mod·x/sync를 함께 올립니다. 따라서 `go vet`, `go fix`의 분석기도 새 x/tools 기준이 됩니다.
  - 예: 새 printf 분석기는 `fmt.Println("foo\n")`을 더 이상 지적하지 않습니다 ([golang/go#80256](https://go.dev/issue/80256)). 그래서 Go 저장소가 x/tools를 올릴 때 한 것과 같이 vet 테스트 기대값(`cmd/vet/testdata/print/print.go`)도 맞춥니다.
- 최신 x/net의 http2는 `x/net/internal/httpsfv`를 사용합니다. 그래서 Go 1.27과 같은 방식으로 이 패키지를 `net/http/internal/httpsfv`에 번들하고, net/http 번들 설정과 의존성 규칙(`go/build/deps_test.go`)을 맞춥니다.
- 최신 모듈들은 `go 1.26.0`을 요구하므로 `go mod tidy`가 go 줄을 `go 1.26.0`으로 바꿉니다. 그런데 cmd/dist는 `go 1.26` 형식이어야 빌드하므로, vendoring을 마친 뒤 원래 값으로 되돌립니다. 언어 버전은 둘 다 go1.26입니다.

## actions/go-versions 패키지를 쓰지 않는 이유

[actions/go-versions](https://github.com/actions/go-versions)의 패키지는 GitHub Actions 러너의 tool cache 전용입니다.
최상위 `go/` 디렉터리 없이 러너용 `setup.sh`가 함께 들어 있고, SHA256도 공식 배포본과 다릅니다.
서버에 풀어서 설치하는 용도에는 공식 tarball을 그대로 쓰는 편이 맞습니다.
