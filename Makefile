.PHONY: all build clean

all: build

build:
	mkdir -p build
	cd build && cmake -DCMAKE_BUILD_TYPE=Release ..
	cd build && cmake --build . -- -j

clean:
	rm -rf build
