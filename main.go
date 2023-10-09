package main

import (
	"fmt"
	"time"
)

func main() {
	ch := make(chan int)

	go func() {
		time.Sleep(2 * time.Second)
		ch <- 123
	}()

	select {
	case value := <-ch:
		fmt.Println("Received value from ch:", value)
	default:
		fmt.Println("No value available from ch")
	}
}