<!-- xupdate -->
## golang.org/x 모듈 최신화 빌드 (비공식)

`${FILE}`은 공식 go${VERSION} 소스에서 표준 라이브러리(std)와 툴체인(cmd)에 포함된 golang.org/x/net, x/text, x/sys를 최신으로 올려 다시 빌드한 배포본입니다.
`go version`은 그대로 `go${VERSION}`이며, x/net에서 생성되는 net/http 번들 코드도 새 버전으로 다시 생성했습니다.
표의 나머지 모듈은 Go 모듈 버전 선택(MVS)에 따라 함께 올라간 것입니다.
go vet, go fix, go test가 쓰는 x/tools는 공식 버전으로 고정해서 분석 결과가 공식 배포본과 같습니다.
코드 생성용 보조 모듈(빌드에는 쓰이지 않음)의 golang.org/x 의존성도 최신으로 올렸습니다.
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
