package main 


func main(){
	a := make([]int,1,1)
	a[0] = 123
	go func(a []int){
		a[0] = 321
	}(a)
	time.Sleep
	fmt.Println(a[0])
}