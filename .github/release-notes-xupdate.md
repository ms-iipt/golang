<!-- xupdate -->
## golang.org/x 모듈 최신화 빌드 (비공식)

`${FILE}`은 공식 go${VERSION} 소스에서 표준 라이브러리(std)와 툴체인(cmd)에 포함된 golang.org/x/net, x/text, x/sys를 최신으로 올려 다시 빌드한 배포본입니다.
`go version`은 그대로 `go${VERSION}`이며, net/http의 HTTP/2 구현(h2_bundle.go)도 새 x/net으로 다시 생성했습니다.
표의 나머지 모듈은 Go 모듈 버전 선택(MVS)에 따라 함께 올라간 것이며, 이에 따라 go vet과 go fix도 새 x/tools 분석기를 씁니다.
예를 들어 `fmt.Println("foo\n")`은 더 이상 경고하지 않습니다([golang/go#80256](https://go.dev/issue/80256)).
같은 파일이 저장소의 `archives/`에도 있습니다.

${TABLE}

- SHA256: `${SHA256}`
- 빌드·테스트 로그: ${RUN_URL}

```sh
curl -fLO ${DOWNLOAD_URL}
curl -fLO ${DOWNLOAD_URL}.sha256
sha256sum -c ${FILE}.sha256

sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf ${FILE}
```
<!-- /xupdate -->
