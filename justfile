build:
  @zig build

lint: build
  @zig build lint

test: build
  clear
  @[ -d test/static/sandbox/Scripts ] || mkdir -p test/static/sandbox/Scripts
  @#@unzip test/static/sandbox/scripts.zip -d test/static/sandbox/Scripts/
  @zig build test --summary all

release: