package main

import (
	"fmt"
)

func main() {
	A()
}

func A1(a int){
	fmt.Println(a)
}

func A(){
	a,b := 1,2
	defer A1(a)	// 此刻a=1已经在defer结构体内复制好数据了，不受外部a的影响

	a = a + b
	fmt.Println(a,b)
}