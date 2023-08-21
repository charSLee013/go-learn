#!/usr/bin/env bash

go build -gcflags="-N -l" -o main.o main.go && go tool objdump -S main.o > main.s