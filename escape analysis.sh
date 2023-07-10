#!/usr/bin/env bash 

go build --gcflags="-l -m"
go run main.go