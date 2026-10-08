#!/usr/bin/env bash
# go.dev 공식 Go 배포본을 내려받아 go.dev 릴리스 인덱스에 게시된 SHA256과 대조한다.
#
#   scripts/fetch-go.sh <version> [platform]
#
#   version   예: 1.26.8 (go1.26.8 도 허용)
#   platform  <GOOS>-<GOARCH> 또는 src(소스), 기본값 linux-amd64
#
# 결과물 ($OUT_DIR, 기본값 dist):
#   go<version>.<platform>.tar.gz          공식 파일 그대로
#   go<version>.<platform>.tar.gz.sha256   sha256sum -c 용
set -euo pipefail

version="${1:?usage: $0 <version> [platform]}"
version="${version#go}"
platform="${2:-linux-amd64}"
out_dir="${OUT_DIR:-dist}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?((rc|beta)[0-9]+)?$ ]] ||
  [[ ! "$platform" =~ ^([a-z0-9]+-[a-z0-9]+|src)$ ]]; then
  echo "error: invalid version or platform: $version $platform" >&2
  exit 1
fi

file="go${version}.${platform}.tar.gz"

# include=all: 최신 패치가 아닌 이전 버전도 인덱스에서 찾을 수 있게 한다.
expected="$(curl -fsSL 'https://go.dev/dl/?mode=json&include=all' |
  jq -r --arg f "$file" '.[].files[] | select(.filename == $f) | .sha256')"
if [[ -z "$expected" ]]; then
  echo "error: $file is not listed on go.dev/dl" >&2
  exit 1
fi

mkdir -p "$out_dir"
cd "$out_dir"
curl -fsSL --retry 3 -o "$file" "https://go.dev/dl/$file"
echo "$expected  $file" | sha256sum -c -
echo "$expected  $file" > "$file.sha256"
