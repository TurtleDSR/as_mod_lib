build:
  @zig build

docs: build
  @zig build docs

test: build
  @zig build test --summary all