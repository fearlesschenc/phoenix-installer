.PHONY: build

build:
	docker build . -t registry.cn-hangzhou.aliyuncs.com/fearlesschenc/containers/phoenix/installer:latest
