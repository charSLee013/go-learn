// package main

// import (
// 	"fmt"
// 	"reflect"
// )

// type MyInterface interface {
// 	ExportedMethod()
// 	unexportedMethod()
// }

// type MyStruct struct{}

// func (s *MyStruct) ExportedMethod() {
// 	fmt.Println("Exported method called")
// }

// func (s *MyStruct) unexport1() {
// 	fmt.Println("Unexported method called")
// }

// func (s *MyStruct) unexportedMethod() {
// 	fmt.Println("Unexported method called")
// }

// func main() {
// 	myStruct := &MyStruct{}
// 	myInterface := (*MyInterface)(nil)

// 	structType := reflect.TypeOf(myStruct)
// 	interfaceType := reflect.TypeOf(myInterface).Elem()

// 	structNumMethod := structType.NumMethod()
// 	interfaceNumMethod := interfaceType.NumMethod()

// 	fmt.Println("Number of methods for struct:", structNumMethod)
// 	fmt.Println("Number of methods for interface:", interfaceNumMethod)

// 	firstMethod := structType.Method(0)
// 	fmt.Printf("[Struct]Func name: %v \t receiver: %v\t func: %v\n", firstMethod.Name, firstMethod.Type,firstMethod.Func)

// 	firstMethodOfInterface := interfaceType.Method(0)
// 	fmt.Printf("[Interface]Func name: %v \t receiver: %v\t func: %v\n", firstMethodOfInterface.Name, firstMethodOfInterface.Type,firstMethodOfInterface.Func)

// 	// 通过反射调用 ExportedMethod 方法
// 	methodValue := reflect.ValueOf(myStruct).MethodByName("ExportedMethod")
// 	methodValue.Call(nil)
// }

package main

import (
	"fmt"
	"reflect"
)

func main() {
	num := 10
	value := reflect.ValueOf(num)

	fmt.Println("原始值:", num) // 输出: 原始值: 10

	// 修改反射值
	// value.

	fmt.Println("修改后的值 (反射):", value.CanInt()) // 输出: 修改后的值 (反射): 20
	fmt.Println("原始值:", num) // 输出: 原始值: 20
}
