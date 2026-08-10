# makesh
makesh is a smart approach to hierarchical make builds that avoids nasty embeddings of shell code in makefiles

## motivation
When writing Makefiles, people often come up with nasty ad hoc solutions:
```Makefile
.PHONY: build
build:
	@while IFS= read -r -u 3 cfile; do \
		context=$$(dirname "$$cfile"); \
		cname=$$(basename "$$cfile"); \
		\
		if [ "Containerfile" = "$$cname" ]; then \
			cname=$$(basename "$$context"); \
		fi; \
		\
		podman build \
			--cap-add SYS_ADMIN,NET_ADMIN \
			--file "$$cfile" \
			--tag "$$cname:latest" \
			"$$context" || exit 1; \
		\
		version=$$(podman image inspect "$$cname:latest" | jq -r '.[0].Labels["org.opencontainers.image.version"] // empty'); \
		if [ -n "$$version" ]; then \
			podman tag "$$cname:latest" "$$cname:$$version"; \
		fi; \
	done < <(find . -maxdepth 3 -type f -name "*Containerfile")
```

Embedding shell code in Makefiles is error prone, nasty and hard to read. Makefiles were originally intended as build recipes for the C compiler that used pattern matching, compile instructions and a crude caching mechanism to assemble binary objects. Nowadays, people writing Makefiles often don't care about assembling binaries and frankly most of make's features. They just want a command runner because the compiling and caching is handled by more sophisticated toolchains such as containerized builds that they intend to invoke. In such setups, a Makefile should essentially be a collection of named shell scripts that implement the desired operations and without proper thinking that leads to nasty solutions such as the above.

## solution
As a first improvment, we might instead implement our operations as a collection of .sh files and thus drastically simplify our Makefile:
```Makefile
.PHONY: build
build:
    @bash scripts/build.sh
```

This is much cleaner. But often we simply don't want an extra *scripts* folder where we store our Makefile operations. Either because our operations are too simplistic to justify that or because we have many and really look for a hierarchical approach to building. As it turns out, we can use a generic [Makefile](Makefile) that sets up a hierarchical build environment by looking for `Makefile.sh` in folders of our project.

Folders that contain a `Makefile.sh` are called **Modules**. Functions with ordinary names in `Makefile.sh` are called **Targets**. Functions starting with `_` are helpers that may be used from but are not themselves **Targets**. Each `Makefile.sh` must at least contain a **Target** `init`. **Note**: Run time variables passed via `make var=val` can be retrieved in **Targets** via `$(_kv "var" "$@")` as `var=val` or via `$(_v "var" "$@")` for the value alone.
```bash
init() {
    find . -maxdepth 3 -type f -name "*Containerfile" | while IFS= read -r cfile; do
        context=$(dirname "$cfile")
        cname=$(basename "$cfile")

        if [ "Containerfile" = "$cname" ]; then
            cname=$(basename "$context")
        fi

        podman build \
            --cap-add SYS_ADMIN,NET_ADMIN \
            --file "$cfile" \
            --env $(_kv "VAR" "$@") \
            --tag "$cname:latest" \
            "$context" || return 1

        version=$(podman image inspect "$cname:latest" | jq -r '.[0].Labels["org.opencontainers.image.version"] // empty')

        if [ -n "$version" ]; then
            podman tag "$cname:latest" "$cname:$version"
        fi
    done
}
```
Additional **Targets** can be implemented such as in [example/foo/Makefile.sh](example/foo/Makefile.sh).

## trying it
Check out this repo and try the following:
- make
- make ?
- make //?
- make //
- make all
- make example/foo//?
- make example/foo
- make example/foo//init
- make example/foo//test?
- make example/foo//test
- make example/foo//test var=foo
- make example/bar//?

## using it
Done tinkering around? Good.
```bash
make make.sh
```
will compile a bash script `make.sh` with all of the features you just explored (except for compiling to bash). If you have **GNU Make 3.81** or greater, you can compile it yourself; otherwise, download from releases. Check in `make.sh` at the root of your project, implement `Makefile.sh` files in folders as needed and from now on run
- ./make.sh
- ./make.sh ?
- ./make.sh all
- ./make.sh help
- ./make.sh //
- ./make.sh vendor//compress

or whatever you choose to implement.

## moral
To really do something, a computer program has to eat and give birth to itself. All else is just idle tinkering around that achieves nothing but global shift without any change of state.

## quirks
On MacOS, you might encounter following problem.
```
make ?
zsh: no matches found: ?
```

To prevent that from happening:
```
echo "setopt nonomatch" >> ~/.zshrc
source ~/.zshrc
```
