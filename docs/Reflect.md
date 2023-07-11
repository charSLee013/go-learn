# Reflect 反射

## 简介

在计算机科学领域，反射是指一类应用，它们能够自描述和自控制。也就是说，这类应用通过采用某种机制来实现对自己行为的描述（`self-representation`）和监测（`examination`），并能根据自身行为的状态和结果，调整或修改应用所描述行为的状态和相关的语义。

每种语言的反射模型都不同，并且有些语言根本不支持反射。Golang语言实现了反射，反射机制就是在运行时动态的调用对象的方法和属性，官方自带的reflect包就是反射相关的，只要包含这个包就可以使用。

Golang 实现的反射是建立在 Go 的**类型系统**之上的，并且与**接口**密切相关。
> 你可以通过[类型系统](./type.md) 和 [接口](./interface.md) 深入了解

我们想要获取运行时候的类型，但是`runtime`的类型并没有导出供程序员使用
因此`reflect`自己又定义了一套`Type interface` 来跟`runtime`的一一对应

```golang
// rtype is the common implementation of most values.
// It is embedded in other struct types.
//
// rtype must be kept in sync with ../runtime/type.go:/^type._type.
type rtype struct {
	size       uintptr
	ptrdata    uintptr // number of bytes in the type that can contain pointers
	hash       uint32  // hash of type; avoids computation in hash tables
	tflag      tflag   // extra type information flags
	align      uint8   // alignment of variable with this type
	fieldAlign uint8   // alignment of struct field with this type
	kind       uint8   // enumeration for C
	// function for comparing objects of this type
	// (ptr to object A, ptr to object B) -> ==?
	equal     func(unsafe.Pointer, unsafe.Pointer) bool
	gcdata    *byte   // garbage collection data
	str       nameOff // string form
	ptrToThis typeOff // type for pointer to this type, may be zero
}
```

## `TypeOf`

`reflect`提供了`TypeOf`函数，用来获取对象的类型信息

```golang
// TypeOf returns the reflection Type that represents the dynamic type of i.
// If i is a nil interface value, TypeOf returns nil.
func TypeOf(i any) Type {
	eface := *(*emptyInterface)(unsafe.Pointer(&i))
	return toType(eface.typ)
}
```
他接受一个任意类型的非空对象，然后返回一个`reflect.Type`类型的返回值


其中`emptyInterface`的定义如下

```golang
// emptyInterface is the header for an interface{} value.
type emptyInterface struct {
	typ  *rtype
	word unsafe.Pointer
}
```
因为`rtype`类型实现了`Type`接口，接下来就是将`typ`包装为 `reflect.Type` 类型并返回


接下来继续讲解`Type`类型，下面是接口定义
```golang
type Type interface {
	// 内存对齐
	Align() int
	FieldAlign() int
	// 方法
	Method(int) Method
	MethodByName(string) (Method, bool)
	NumMethod() int
	Name() string
	PkgPath() string
	Size() uintptr
	String() string
	Kind() Kind
	Implements(u Type) bool
	AssignableTo(u Type) bool
	ConvertibleTo(u Type) bool
	Comparable() bool
	...
}
```

我们挑选几个重点的来讲解和串联反射如何是跟类型系统和接口一起工作的


### **NumMethod() int**
对于非接口类型来说，返回*导出的方法(大写开头)*数量
对于接口类型来说，返回可导出和*不可导出的方法(小写开头)*数量


### **Method(int) Method** && **MethodByName(string) (Method, bool)**

`Method` 返回类型方法集中的第 `i` 个方法。
如果引用的 `i` 不在` [0, NumMethod())` 范围内会发生 `panic`。

对于非接口类型 `T` 或 `*T`，返回的 `Method` 的 `Type` 字段和 `Func` 字段描述了一个方法,并且第一个参数是接收者(即与之关联的结构体),在 Golang 中，方法是与结构体或类型相关联的函数，而且`Type` 和 `Func` 组成了该方法的*签名*

下面是`Method`的源代码

```golang
type Method struct {
	// Name 是方法名。
	Name string

	// PkgPath 是限定小写（未导出）方法名的包路径。
	// 对于大写（导出）的方法名，它为空。
	// PkgPath 和 Name 的组合在方法集中唯一标识一个方法。
	// 参见 https://golang.org/ref/spec#Uniqueness_of_identifiers
	PkgPath string

	Type  Type  // 方法类型(即与之先关联的结构体)
	Func  Value // 携带第一个参数(即与之关联的结构体)的函数
	Index int   // Type.Method 的索引
}
```

我们继续看下面这个例子

```golang
type MyStruct struct {
	data int
}

func (s *MyStruct) MyMethod() {
	// 方法的实现
}
```

在这个例子中，`MyMethod` 是一个方法，与结构体 `MyStruct` 相关联。当我们调用 `MyMethod` 时，我们需要提供一个 `MyStruct` 类型的对象作为方法的接收者，类似于 `myStructObj.MyMethod()`。
可以理解为Python中`MeMethod(self)`中`self`是作为方法的第一个参数，表明该方法所属的对象
在反射中，返回的 `Method` 结构体的 `Func` 字段描述的函数就是 `MyMethod`，它的第一个参数就是 `MyStruct` 类型的接收者。

但是对于一个接口类型来说，，返回的 `Method` 结构体的 `Type` 字段表示方法的签名（即方法的参数和返回值类型），但没有指定具体的接收者类型，并且该 `Method` 结构体的 `Func` 字段为 `nil`

方法按字典顺序排序(并不是无序的)。

**MethodByName(string) (Method,bool)**  根据传入进来的方法名称返回存在的方法，否则返回 `nil,false`

## **ValueOf(i any) Value**
说完获取对象的数据类型，该说说如何通过反射修改变量的值

```golang
// ValueOf 返回一个新的 Value，该 Value 的具体值被初始化为接口 i 中存储的具体值。ValueOf(nil) 返回零值 Value。
func ValueOf(i any) Value {
	if i == nil {
		return Value{}
	}

	// TODO: 或许允许 Value 的内容存储在栈上。
	// 目前我们始终将内容逃逸到堆上。这样做在一些地方会更方便（参见下面的 chanrecv/mapassign 注释）。
	escapes(i)

	return unpackEface(i)
}
```

注意！获得的值是原来的拷贝，修改通过反射获得的值并不会改变原来对象的值，比如下面的这个例子

```golang
package main

import (
	"fmt"
	"reflect"
)

func main() {
	num := 10
	value := reflect.ValueOf(&num).Elem() // 获取可修改的反射值

	fmt.Println("原始值:", num) // 输出: 原始值: 10

	// 修改反射值
	value.SetInt(20)

	fmt.Println("修改后的值 (反射):", value.Int()) // 输出: 修改后的值 (反射): 20
	fmt.Println("原始值:", num) // 输出: 原始值: 20
}

```


## 例子

```golang
package main

import (
	"fmt"
	"reflect"
)

type MyInterface interface {
	ExportedMethod()
	unexportedMethod()
}

type MyStruct struct{}

func (s *MyStruct) ExportedMethod() {
	fmt.Println("Exported method called")
}

func (s *MyStruct) unexport1() {
	fmt.Println("Unexported method called")
}

func (s *MyStruct) unexportedMethod() {
	fmt.Println("Unexported method called")
}

func main() {
	myStruct := &MyStruct{}
	myInterface := (*MyInterface)(nil)

	structType := reflect.TypeOf(myStruct)
	interfaceType := reflect.TypeOf(myInterface).Elem()

	structNumMethod := structType.NumMethod()
	interfaceNumMethod := interfaceType.NumMethod()

	fmt.Println("Number of methods for struct:", structNumMethod)
	fmt.Println("Number of methods for interface:", interfaceNumMethod)

	firstMethod := structType.Method(0)
	fmt.Printf("[Struct]Func name: %v \t receiver: %v\t func: %v\n", firstMethod.Name, firstMethod.Type,firstMethod.Func)

	firstMethodOfInterface := interfaceType.Method(0)
	fmt.Printf("[Interface]Func name: %v \t receiver: %v\t func: %v\n", firstMethodOfInterface.Name, firstMethodOfInterface.Type,firstMethodOfInterface.Func)

	// 通过反射调用 ExportedMethod 方法
	methodValue := reflect.ValueOf(myStruct).MethodByName("ExportedMethod")
	methodValue.Call(nil)
}
```


# 参考

[go reflect](https://pkg.go.dev/reflect)
[Golang的反射reflect深入理解和示例](https://zhuanlan.zhihu.com/p/315589978)