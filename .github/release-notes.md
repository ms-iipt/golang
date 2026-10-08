go.dev 공식 배포본 [`${FILE}`](https://go.dev/dl/${FILE})을 수정 없이 올린 파일입니다.

- SHA256: `${SHA256}`
- 변경 사항: https://go.dev/doc/devel/release#go${VERSION}

## 설치

```sh
curl -fLO ${DOWNLOAD_URL}
curl -fLO ${DOWNLOAD_URL}.sha256
sha256sum -c ${FILE}.sha256

sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf ${FILE}
export PATH=$PATH:/usr/local/go/bin   # 계속 쓰려면 ~/.profile 에 추가
go version                            # go version go${VERSION} linux/amd64
```
