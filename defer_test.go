package main

import "testing"

func BenchmarkDefer(b *testing.B){
  for i:= 0; i< b.N; i++{
    Defer(i)
  }
}

func Defer(i int) (r int){
  defer func(){
    r -= 1
    r |= r>>1
    r |= r>>2
    r |= r>>4
    r |= r>>8
    r |= r>>16
    r |= r>>32
    r += 1
  }()
  r = i*i
  return 
}