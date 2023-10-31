#!/usr/bin/env bash 

go build --gcflags="-l -m" main.go
go run main.go