build:
  @zig build

docs: build
  @zig build docs

test: build
  @[ -d test/static/sandbox/ ] || mkdir -p test/static/sandbox
  @zig build test --summary all