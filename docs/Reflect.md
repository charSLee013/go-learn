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
注意的是，同`TypeOf`不同的是，复制过来的值`i`会被显式逃逸到堆上，栈上保留的是指向`i`的指针
然后使用`unpackEface`对`i`进行解包返回指向`Value`类型的指针

```golang
// unpackEface将空接口i转换为Value。

func unpackEface(i any) Value {
	// 将i转换为emptyInterface类型的指针e
	e := (*emptyInterface)(unsafe.Pointer(&i))

	// 注意：在我们确定e.word是指针还是非指针之前，不要读取e.word。
	t := e.typ

	// 如果t为空，则返回一个空的Value
	if t == nil {
		return Value{}
	}

	// 根据t的Kind确定元数据标志位f
	f := flag(t.Kind())

	// 如果t是通过间接方式传递（indirect），则设置flagIndir标志位
	if ifaceIndir(t) {
		f |= flagIndir
	}

	// 返回一个包含类型t、数据指针e.word和标志位f的Value
	return Value{t, e.word, f}
}
```


下面是返回值`Value`结构体的源代码
```golang
// Value是对Go值的反射接口。

type Value struct {
    typ *rtype  // 指向该值的元数据指针
    ptr unsafe.Pointer  // 数据的指针
    flag  // 元数据标志位

    // flag元数据标志位的含义：
    //  - flagStickyRO: 是否通过未公开的非嵌入字段获取，从而为只读
    //  - flagEmbedRO: 是否通过未公开的嵌入字段获取，从而为只读
    //  - flagIndir: 是否val保存了一个指向数据的指针
    //  - flagAddr: v.CanAddr是否为true（implies flagIndir）
    //  - flagMethod: v是否为一个方法值

    // 方法值表示某个接收器r的柯里化方法调用，例如r.Read。typ+val+flag位描述了接收器r，
    // 但是flag的Kind位表示Func（方法是函数），并且flag的最高位给出了r的类型的方法表中的方法编号。
}
```

### 陷阱
想象下面的代码
```golang
package main

import "reflect"

func main() {
	a:= 123
	v:= reflect.ValueOf(a)
	v.SetInt(321)
	println(a)
}
```

我们定义了一个`int`类型然后使用反射`reflect.ValueOf`获得变量的值，然后修改`int`类型为321，最后打印出来
```bash
panic: reflect: reflect.Value.SetInt using unaddressable value
```

但实际运行起来确发生了`panic`，发生了什么?
如果你还记得Golang的操作语义的话
> As in all languages in the C family, everything in Go is passed by value. That is, a function always gets a copy of the thing being passed, as if there were an assignment statement assigning the value to the parameter. For instance, passing an int value to a function makes a copy of the int, and passing a pointer value makes a copy of the pointer, but not the data it points to
> 具体可以查看[官方文档FAQ部分](https://go.dev/doc/faq#pass_by_value)

`a`自然是存在于栈上的一个整数，根据Golang定义的值拷贝传参，我们其实只是传入了"123"这个数字而已，而reflect包操作的值必须可以寻址(addressable),即有一个内存地址可以变更。但非地址able的值如a没有一个内存地址可以变更,它只是一个不可变的拷贝。

换句话说,当你传入一个值类型变量给`reflect.ValueOf`,你会获得这个值的一个拷贝,而丢失了指向原始变量的链接。所以reflect包无法修改这个非地址able的值,否则就破坏了Go的值不可变性。

那什么是**addressable value**?

简单来说,所有可以取地址的变量都是addressable的,比如指针,slice,map,channel等。

而在我们的例子中可以改成下面的代码
```golang
	var a *int = new(int)
	*a = 123
	// reflect.ValueOf 返回值的副本,对指针也是一层间接引用
	v:= reflect.ValueOf(a)
	// 需要先 Elem() 解引用,得到实际的值对象
	v.Elem().SetInt(321)
	println(*a)
```

这里我们传入的是`*int`类型，是一个`int`类型的指针，然后通过`Elem()`解应用后的`Value`调用`SetInt`等方法修改

# 参考

[go reflect](https://pkg.go.dev/reflect)
[Golang的反射reflect深入理解和示例](https://zhuanlan.zhihu.com/p/315589978)