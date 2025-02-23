#!/bin/sh
RECOMMENDED_ELM_VERSION=0.19.1

# map tools from project go modules

golint() {
	GOARCH='' go run golang.org/x/lint/golint "$@"
}

bbolt() {
	go run go.etcd.io/bbolt/cmd/bbolt "$@"
}

air() {
	go run github.com/cosmtrek/air "$@"
}

siot_install_proto_gen_go() {
	cd ~ && go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	cd - || exit
}

siot_install_frontend_deps() {
	(cd "frontend" && npm install)
	(cd "frontend/lib" && npm ci)
}

siot_check_elm() {
	if ! npx elm --version >/dev/null 2>&1; then
		echo "Please install elm >= 0.19"
		echo "https://guide.elm-lang.org/install.html"
		return 1
	fi

	version=$(npx elm --version)
	if [ "$version" != "$RECOMMENDED_ELM_VERSION" ]; then
		echo "found elm $version, recommend elm version $RECOMMENDED_ELM_VERSION"
		echo "not sure what will happen otherwise"
	fi

	return 0
}

siot_setup() {
	siot_install_frontend_deps
	# the following is to work around a race condition
	# where the first time you run npx elm, you get an error:
	# elm: Text file busy
	(cd frontend && (npx elm || true))
	# make sure elm-spa auto-generated stuff is set up
	(cd frontend && npx elm-spa build)
	return 0
}

siot_build_frontend() {
	(cd "frontend" && npx elm-spa build) || return 1
	gzip -f frontend/public/dist/elm.js
	return 0
}

siot_version() {
	git describe --tags HEAD
}

siot_build() {
	siot_build_frontend || return 1
	BINARY_NAME=siot
	if [ "${GOOS}" = "windows" ]; then
		BINARY_NAME=siot.exe
	fi
	CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=$(siot_version)" -o $BINARY_NAME cmd/siot/main.go || return 1
	return 0
}

siot_build_arm() {
	siot_build_frontend || return 1
	GOARCH=arm GOARM=7 go build -ldflags="-s -w -X main.version=$(siot_version)" -o siot_arm cmd/siot/main.go || return 1
	return 0
}

siot_build_arm_debug() {
	siot_build_frontend || return 1
	GOARCH=arm GOARM=7 go build -ldflags="-s -w -X main.version=$(siot_version)" -o siot_arm cmd/siot/main.go || return 1
	return 0
}

siot_deploy() {
	siot_build_frontend || return 1
	gcloud app deploy cmd/portal || return 1
	return 0
}

siot_run() {
	echo "run args: $*"
	go build -ldflags="-X main.version=$(siot_version)" -o siot -race cmd/siot/main.go || return 1
	./siot "$@"
	return 0
}

# run siot_mkcert first
siot_run_tls() {
	echo "run args: $*"
	export SIOT_NATS_TLS_CERT=server-cert.pem
	export SIOT_NATS_TLS_KEY=server-key.pem
	siot_build_frontend || return 1
	go run cmd/siot/main.go "$@" || return 1
	return 0
}

# please install mkcert and run mkcert -install first
siot_mkcert() {
	mkcert -cert-file server-cert.pem -key-file server-key.pem localhost ::1
}

find_src_files() {
	find . -not \( -path ./frontend/src/Spa/Generated -prune \) -not \( -path ./assets -prune \) -name "*.go"
}

siot_watch_go() {
	echo "watch args: $*"
	air serve -dev "$*"
}

siot_watch_elm() {
	(cd frontend && npx elm-watch hot) || false
}

siot_watch() {
	npx run-pty \
		% /bin/sh -c ". ./envsetup.sh && siot_watch_elm" \
		% /bin/sh -c ". ./envsetup.sh && siot_watch_go $*"
}

# TODO finish this and add to siot_test ...
check_go_format() {
	gofiles=$(find . -name "*.go")
	unformatted=$(gofmt -l "$gofiles")
	if [ -n "$unformatted" ]; then
		return 1
	fi
	return 0
}

siot_test_frontend() {
	(cd frontend && npx elm-test || return 1) || return 1
	(cd frontend && npx elm-review || return 1) || return 1
}

siot_test_frontend_lib() {
	(cd ./frontend/lib && npm run lint || return 1) || return 1
	echo "Starting SimpleIOT..."
	./siot serve --store siot_test_frontend_lib.sqlite --resetStore 2>/dev/null &
	PID=$!
	sleep 1
	(cd ./frontend/lib && npm run test || return 1)
	CODE=$?
	echo "Stopping SimpleIOT..."
	kill -s SIGINT $PID
	wait $PID
	echo "SimpleIOT Stopped"
	if [ "$CODE" = "0" ]; then
		rm siot_test_frontend_lib.sqlite
	fi
}

siot_frontend_fix() {
	(cd frontend && npx elm-review --fix-all)
}

# please run the following before pushing -- best if your editor can be set up
# to do this automatically.
siot_test() {
	siot_build_frontend || return 1
	siot_test_frontend || return 1
	go test -p=1 -race "$@" ./... || return 1
	golangci-lint run || return 1
	return 0
}

# following can be used to set up influxdb for local testing
siot_setup_influx() {
	export SIOT_INFLUX_URL=http://localhost:8086
	#export SIOT_INFLUX_USER=admin
	#export SIOT_INFLUX_PASS=admin
	export SIOT_INFLUX_DB=siot
}

siot_protobuf_go() {
	protoc --proto_path=internal/pb internal/pb/*.proto --go_out=./ || return 1
}

siot_protobuf_js() {
	protoc --proto_path=internal/pb internal/pb/*.proto --js_out=import_style=commonjs,binary:./frontend/lib/protobuf/ || return 1
}

siot_protobuf() {
	echo "generating protobufs"
	siot_protobuf_go
	siot_protobuf_js
}

siot_edge_run() {
	go run cmd/edge/main.go "$*"
}

# download goreleaser from https://github.com/goreleaser/goreleaser/releases/
# and put in /usr/local/bin
# This can be useful to test/debug the release process locally
siot_goreleaser_build() {
	goreleaser build --skip-validate --rm-dist
}

# before releasing, you need to tag the release
# you need to provide GITHUB_TOKEN in env or ~/.config/goreleaser/github_token
# generate tokens: https://github.com/settings/tokens/new
# enable repo and workflow sections
siot_goreleaser_release() {
	#TODO add depend build to goreleaser config
	#siot_build_frontend
	goreleaser release --rm-dist
}

# dblab keyboard shortcuts
# - Ctrl+space execute query
# - Ctrl+H,J,K,L move to panel left,below,above,right
# see more keybindings here: https://github.com/danvergara/dblab#key-bindings
siot_dblab() {
	STORE=siot.sqlite
	if [ "$1" != "" ]; then
		STORE=$1
	fi
	go run github.com/danvergara/dblab@latest --db "$STORE" --driver sqlite3
}

siot_mdbook() {
	mdbook serve -p 3333
}

siot_mdbook_cleanup() {
	rm -rf book
}

siot_deploy_docs() {
	(cd /scratch/bec/ops/ &&
		ansible-playbook -i production tmpdir.yml --tags docs.simpleiot.org)
}
