#!/usr/bin/env bash
# go.dev 공식 Go 소스에서 표준 라이브러리(std)와 툴체인(cmd)이 vendoring 한 golang.org/x
# 모듈을 최신으로 올린 뒤 배포본(tar.gz)을 빌드한다. Go 버전(VERSION 파일)은 바꾸지 않는다.
#
# 절차는 Go 저장소의 src/README.vendor, cmd/internal/moddeps 테스트와 같다:
#   go get <module>@latest → go mod tidy → go mod vendor → 번들/syscall 코드 재생성 → make.bash -distpack
#
#   scripts/build-xupdate.sh <version> [module...]
#
#   version  예: 1.26.8
#   module   기본값: golang.org/x/net golang.org/x/text golang.org/x/sys
#            std, cmd 각각의 go.mod 에 있는 모듈만 올린다. MVS 에 따라 다른 모듈도 함께 올라갈 수 있다.
#
# 환경 변수:
#   GOOS, GOARCH      대상 플랫폼, 기본값 linux/amd64 (호스트와 다르면 교차 빌드)
#   GOROOT_BOOTSTRAP  부트스트랩 Go, 기본값: PATH 의 go
#   OUT_DIR           결과물 위치, 기본값 dist
#   WORK_DIR          작업 디렉터리, 기본값: 임시 디렉터리 (빌드된 트리는 WORK_DIR/go)
#
# 결과물 ($OUT_DIR):
#   go<version>.<goos>-<goarch>.xupdate.tar.gz          배포본 (압축을 풀면 go/)
#   go<version>.<goos>-<goarch>.xupdate.tar.gz.sha256   sha256sum -c 용
#   go<version>.<goos>-<goarch>.xupdate.md              바뀐 모듈 버전 표
set -euo pipefail

version="${1:?usage: $0 <version> [module...]}"
version="${version#go}"
shift
modules=(golang.org/x/net golang.org/x/text golang.org/x/sys)
if [[ $# -gt 0 ]]; then
  modules=("$@")
fi

goos="${GOOS:-linux}"
goarch="${GOARCH:-amd64}"
name="go$version.$goos-$goarch.xupdate"
unset GOOS GOARCH GOROOT GOFLAGS
export GOTOOLCHAIN=local GOWORK=off LC_ALL=C
export GOROOT_BOOTSTRAP="${GOROOT_BOOTSTRAP:-$(go env GOROOT)}"

scripts="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${OUT_DIR:-dist}"
out_dir="$(cd "${OUT_DIR:-dist}" && pwd)"
work="${WORK_DIR:-$(mktemp -d)}"
mkdir -p "$work"
work="$(cd "$work" && pwd)"
goroot="$work/go"

# 1. 공식 소스를 받아(SHA256 검증) 호스트용으로 빌드한다.
#    std/cmd 모듈 작업은 그 트리에서 빌드한 go 로 해야 한다 (src/README.vendor).
OUT_DIR="$work" "$scripts/fetch-go.sh" "$version" src
rm -rf "$goroot"
tar -C "$work" -xzf "$work/go$version.src.tar.gz"
(cd "$goroot/src" && ./make.bash)
export PATH="$goroot/bin:$work/bin:$PATH"

# 2. std, cmd 모듈의 go.mod 에 있는 대상 모듈을 최신으로 올린다.
requires() {
  go -C "$1" mod edit -json | jq -r '.Require[] | "\(.Path) \(.Version)"' | sort
}
for mod in std cmd; do
  dir="$goroot/src"
  if [[ $mod == cmd ]]; then dir="$goroot/src/cmd"; fi
  go -C "$dir" mod edit -json | jq -r .Go > "$work/$mod.go"
  requires "$dir" > "$work/$mod.before"
  args=()
  for m in "${modules[@]}"; do
    if cut -d' ' -f1 "$work/$mod.before" | grep -qxF "$m"; then args+=("$m@latest"); fi
  done
  if [[ ${#args[@]} -gt 0 ]]; then
    go -C "$dir" get "${args[@]}"
    go -C "$dir" mod tidy
    go -C "$dir" mod verify
    go -C "$dir" mod vendor
  fi
  requires "$dir" > "$work/$mod.after"
done

# 3. x/net 에서 생성되는 net/http 번들과 x/sys 로 생성되는 syscall 코드를 다시 만든다.
#    x/net 의 http2 가 internal/httpsfv 를 쓰면 net/http 에서 import 할 수 있도록
#    Go 1.27 과 같은 방식으로 net/http/internal/httpsfv 에 번들한다.
xnet="$(go -C "$goroot/src" mod download -json golang.org/x/net | jq -r .Dir)"
httpsfv="$goroot/src/net/http/internal/httpsfv"
if [[ ! -d "$httpsfv" ]] && grep -q '"golang.org/x/net/internal/httpsfv"' "$xnet"/http2/*.go; then
  mkdir "$httpsfv"
  printf '//go:generate bundle -o httpsfv.go -prefix= golang.org/x/net/internal/httpsfv\n\npackage httpsfv\n' \
    > "$httpsfv/httpsfv.go"
  perl -pi -e 's#-import=golang.org/x/net/internal/httpcommon=net/http/internal/httpcommon#$& -import=golang.org/x/net/internal/httpsfv=net/http/internal/httpsfv#' \
    "$goroot/src/net/http/http.go"
  perl -pi -e 's#^(\s*< net/http/internal/httpcommon)$#$1, net/http/internal/httpsfv#' \
    "$goroot/src/go/build/deps_test.go"
  if ! grep -q 'internal/httpsfv=net/http/internal/httpsfv' "$goroot/src/net/http/http.go" ||
    ! grep -q 'net/http/internal/httpcommon, net/http/internal/httpsfv' "$goroot/src/go/build/deps_test.go"; then
    echo "error: failed to wire net/http/internal/httpsfv" >&2
    exit 1
  fi
fi
tools="$(go -C "$goroot/src/cmd" list -m -f '{{.Version}}' golang.org/x/tools)"
GOBIN="$work/bin" go install "golang.org/x/tools/cmd/bundle@$tools"
(cd "$goroot/src" && go generate -run='^//go:generate bundle ' std && go generate syscall internal/syscall/...)

# x/tools 의 printf 분석기는 2026-07 부터 Println 끝의 개행을 보고하지 않는다 (golang/go#80256).
# 새 x/tools 를 쓰면 Go 저장소가 x/tools 를 올리며 고친 것과 같이 vet 테스트 기대값을 맞춘다.
vetprint="$goroot/src/cmd/vet/testdata/print/print.go"
printf_go="$goroot/src/cmd/vendor/golang.org/x/tools/go/analysis/passes/printf/printf.go"
if grep -q 'redundant newline' "$vetprint" 2> /dev/null && ! grep -q 'redundant newline' "$printf_go"; then
  perl -pi -e 's#^(\tfmt\.Println\("foo\\n"\)\s+)// ERROR "Println arg list ends with redundant newline"$#$1// not an error#' "$vetprint"
  if grep -q 'redundant newline' "$vetprint"; then
    echo "error: failed to update $vetprint" >&2
    exit 1
  fi
fi

# 의존 모듈이 "go 1.26.0" 을 요구하면 go get 이 go 줄을 1.26 → 1.26.0 으로 올리지만, cmd/dist 는
# std go.mod 의 go 줄이 "go 1.X" 형식이어야 빌드한다. vendor 와 번들 생성이 끝났으니 원래 값으로 되돌린다.
# (언어 버전은 둘 다 go1.26 으로 같다.)
go -C "$goroot/src" mod edit -go="$(cat "$work/std.go")"
go -C "$goroot/src/cmd" mod edit -go="$(cat "$work/cmd.go")"

# 4. 대상 플랫폼용 배포본을 빌드한다 (공식 배포본과 같은 make.bash -distpack).
(cd "$goroot/src" && GOOS="$goos" GOARCH="$goarch" ./make.bash -distpack)
cp "$goroot/pkg/distpack/go$version.$goos-$goarch.tar.gz" "$out_dir/$name.tar.gz"
(cd "$out_dir" && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256")

# 5. 바뀐 모듈 버전 표
{
  echo "| 모듈 | 위치 | 공식 go$version | 이 빌드 |"
  echo "|---|---|---|---|"
  for mod in std cmd; do
    join -a 1 -a 2 -e - -o 0,1.2,2.2 "$work/$mod.before" "$work/$mod.after" |
      awk -v mod="$mod" '$2 != $3 { printf "| %s | %s | %s | %s |\n", $1, mod, $2, $3 }'
  done
} > "$out_dir/$name.md"

cat "$out_dir/$name.md"
echo "built $out_dir/$name.tar.gz (tree: $goroot)"
