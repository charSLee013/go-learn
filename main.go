package main
 
import (
	"fmt"
	"os"
	"reflect"
)



func main() {
	_, err := os.Open("nonexistent.txt")
	if err != nil {

        DoFiledAndMethod(err)
		// // 使用反射获取错误类型的元数据
		// errType := reflect.TypeOf(err)
		// fmt.Println("错误类型：", errType)

		// // 使用反射获取错误类型的字段
		// for i := 0; i < errType.NumField(); i++ {
		// 	field := errType.Field(i)
		// 	fmt.Printf("字段%d：名称：%s，类型：%v\n", i, field.Name, field.Type)
		// }

		// // 使用反射获取错误类型的方法
		// for i := 0; i < errType.NumMethod(); i++ {
		// 	method := errType.Method(i)
		// 	fmt.Printf("方法%d：名称：%s\n", i, method.Name)
		// }
	}
}


// 通过接口来获取任意参数，然后一一揭晓
func DoFiledAndMethod(input interface{}) {
 
    getType := reflect.TypeOf(input).Elem()
    fmt.Println("get Type is :", getType.Name())
 
    getValue := reflect.ValueOf(input).Elem()
    // fmt.Println("get all Fields is:", getValue)
 
    // 获取成员变量的名称和对应的值
    // 1. 先根据NumField遍历成员的索引值
    // 2. 再通过getType的Field获取其Field
    // 3. 最后通过getValue的Field得到对应的value
    for i := 0; i < getType.NumField(); i++ {
        field := getType.Field(i)
        value := getValue.Field(i)
        fmt.Printf("IDX[%v]: %v = %v\n", i, field.Name, value)
    }
 
    // 获取方法
    // 1. 先获取interface的reflect.Type，然后通过.NumMethod进行遍历
    for i := 0; i < getType.NumMethod(); i++ {
        m := getType.Method(i)
        fmt.Printf("%s: %v\n", m.Name, m.Type)
    }
}