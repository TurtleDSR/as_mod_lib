build:
  @zig build

docs: build
  @zig build docs

test: build
  @[ -d test/sandbox/ ] || mkdir -p test/sandbox
  @zig build test --summary all