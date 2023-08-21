# Defer
> In Golang, the defer keyword is used to delay the execution of a function until the surrounding function completes. The deferred function calls are executed in Last-In-First-Out (LIFO) order.

被`defer`修饰的片段都会延迟在`return`之前执行，比如下面这段代码
```golang
package main

import "fmt"

func main() {
  msg := "hello"

  defer fmt.Println(msg)

  msg = "goodbye"
  return
}
```

编译后的伪指令是如下这样的
```golang
tmp := fmt.Println(msg) // call is recorded
deferproc(tmp) // tmp function is deferred

msg = "goodbye" // msg is changed

runtime.deferreturn()
return
```

`deferproc`传入一个函数的值`tmp`,将`tmp`函数进行注册
注册完成后程序会继续执行后面代码段

直到执行到`retrun`之前的`runtime.deferreturn()`函数,开始依据 `Last-in-First-out`的顺序去

首先来看下 `defer`的[结构体的代码](https://github.com/golang/go/blob/2eca0b1e1663d826893b6b1fd8bd89da98e65d1e/src/runtime/runtime2.go#L1001)
```golang
// _defer 结构体表示延迟调用的入口。
type _defer struct {
	started   bool       // 是否已开始执行
	heap      bool       // 是否在堆上分配
	openDefer bool       // 表示该 _defer 是用于具有开放式延迟调用的函数框架。在整个函数框架中只有一个 _defer 记录（当前可能有0个、1个或多个活跃的延迟调用）。
	sp        uintptr    // 延迟调用发生时的栈指针
	pc        uintptr    // 延迟调用发生时的程序计数器
	fn        func()     // 延迟调用的函数，对于开放式延迟调用可以为 nil
	_panic    *_panic    // 正在执行延迟调用的 panic
	link      *_defer    // G 上的下一个延迟调用，可以指向堆上或栈上的 _defer

	// 如果 openDefer 为 true，则下面的字段记录与具有开放式延迟调用的栈帧和关联函数有关的值。
	// 上面的 sp 将是该栈帧的栈指针，而 pc 将是函数中的 deferreturn 调用的地址。
	fd        unsafe.Pointer // 与栈帧关联的函数数据
	varp      uintptr        // 栈帧的 varp 值
	framepc   uintptr        // 与栈帧关联的当前程序计数器。结合上面的 sp（与栈帧关联的栈指针），framepc/sp 可以作为 pc/sp 对继续通过 gentraceback() 执行堆栈跟踪。
}
```
根据代码和注释，每个字段的功能可以总结如下：

- `started`：表示延迟调用是否已开始执行。
- `heap`：表示延迟调用是否在堆上分配。
- `openDefer`：表示该 `_defer` 结构体是否用于具有开放式延迟调用的函数框架。
- `sp`：记录延迟调用发生时的栈指针。
- `pc`：记录延迟调用发生时的程序计数器。
- `fn`：延迟调用的函数。对于开放式延迟调用，该字段可以为nil。
- `_panic`：正在执行延迟调用的panic。
- `link`：指向G（goroutine）上的下一个延迟调用的指针，可以指向堆上或栈上的 `_defer` 结构体。
- `fd`：与栈帧关联的函数数据。
- `varp`：栈帧的varp值。
- `framepc`：与栈帧关联的当前程序计数器。结合`sp`字段，可以作为继续进行堆栈跟踪的pc/sp对。

`defer`信息会注册到一个链表，当前执行的`goroutine`持有该链表的头节点,查看`goruotine`[结构体](https://github.com/golang/go/blob/28ca813a1373ff3c8845b0145ce915cca73ff182/src/runtime/runtime2.go#L427)

```golang
type g struct {
	...
	_defer    *_defer // innermost defer
	...
}
```
`defer`链表链起来就是一个一个`_defer`结构体
新注册的`defer`会添加到链表头，执行也是从头开始
![defer in goroutine](./images/defer%20in%20goroutine.png)

## 深入
我们继续深入看看 Golang 是如何将`defer`语法糖展开为实际的代码的
现在我们先创建一个如下例子
```golang
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
	defer A1(a)

	a = a + b
	fmt.Println(a,b)
}
```
然后将编译后的二进制文件进行**反汇编**
```bash
go build -gcflags="-N -l" -o main.o main.go 
go tool objdump -S main.o > main.s
# 输出 main 方法的汇编指令
go tool objdump -S -s main.A main.o 
```
- `-N` 表示禁用优化，生成未优化的代码，这样可以保留更多的调试信息。
- `-l` 表示禁用内联优化，保留函数的边界信息。
- `-S` 表示打印带有源代码的反汇编结果。


查看`mian.A`方法的汇编指令，然后我们截取重要的部分如下所示
```asm
	defer A1(a)
  0x4819b8		48c744242801000000	MOVQ $0x1, 0x28(SP)		// 把参数a的值1移动到0x28(SP)位置,也就是复制到堆栈上
  0x4819c1		440f117c2430		MOVUPS X15, 0x30(SP)		 // 通过MOVUPS指令保存了堆栈指针到X15寄存器
  0x4819c7		488d4c2430		LEAQ 0x30(SP), CX		       // LEAQ指令计算参数a在堆栈上的地址0x30(SP),保存到CX寄存器
  0x4819cc		48898c24a0000000	MOVQ CX, 0xa0(SP)		    // 最后将这个地址保存到0xa0(SP)位置
  // 后面在执行defer函数的时候,会从0xa0(SP)位置读取这个地址,再访问该地址取出参数a的值
  0x4819d4		8401			TESTB AL, 0(CX)			
  0x4819d6		488d1563010000		LEAQ main.A.func1(SB), DX	
  0x4819dd		4889542430		MOVQ DX, 0x30(SP)		
  0x4819e2		8401			TESTB AL, 0(CX)			
  0x4819e4		488b542428		MOVQ 0x28(SP), DX		
  0x4819e9		4889542438		MOVQ DX, 0x38(SP)		
  0x4819ee		48894c2458		MOVQ CX, 0x58(SP)		
  0x4819f3		488d442440		LEAQ 0x40(SP), AX		
  0x4819f8		e843d8faff		CALL runtime.deferprocStack(SB)	// defer 方法入栈,
  0x4819fd		0f1f00			NOPL 0(AX)			
  0x481a00		85c0			TESTL AX, AX					
```
在将`defer`函数入栈之后，编译器会在函数返回前插入`deferreturn`调用,按照逆序执行延迟函数
```asm
	defer A1(a)
  0x481b1a		e841ddfaff		CALL runtime.deferreturn(SB)	// 根据LIFO原则依次执行
  0x481b1f		488bac24e0000000	MOVQ 0xe0(SP), BP		
  0x481b27		4881c4e8000000		ADDQ $0xe8, SP			
  0x481b2e		c3			RET				
```

# defer 优化

## 演变过程
为了更佳直观和量化优化后的性能，以下面的代码作为基准测试的标准
```golang
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
```

在终端上执行
```bash
go test bench=.
```

### go-1.12
我们先忽略`painc`和`recover`相关的逻辑，考虑下面的
```golang
func A(){
	defer B(10)
	// code to do something
}
func B(i int){
	...
}
```

编译之后的伪指令可能是这样的
```golang
func A(){
	r := runtime.deferproc(0,B,10)

	// code to do something
	runtime.deferreturn()
	return
}
```
1.12中通过`deferproc`注册`defer`函数信息，`_defer`结构体分配到堆上，然后用链表的形式串联起`defer`执行链
我们直接查看`go-1.12`的[源代码](https://github.com/golang/go/blob/46cb016190389b7e37b21f04e5343a628ca1f662/src/runtime/runtime2.go#L729)是如何定义`_defer`结构体的
```golang
type _defer struct {
	siz     int32	// 延迟调用函数的参数和结果的内存大小,用于堆内存分配
	started bool	// 表示该延迟调用是否已经启动执行
	sp      uintptr // 在defer语句时的堆栈指针,用于恢复堆栈帧
	pc      uintptr	// 在defer语句时的程序计数器,记录调用点
	fn      *funcval	// 等待调用的函数值指针
	_panic  *_panic // 触发延迟调用的panic对象指针,可用于恢复
	link    *_defer // 链表链接指针,用于根据FILO顺序连接_defer结构体
}
```
此时还是在函数的返回之前，通过链表的方式按照FILO顺序依次执行注册的`defer`函数

再来看下性能基准测试的结果
```

```

### go-1.13



### openDefer
> [开发式延迟调用](https://github.com/golang/proposal/blob/master/design/34481-opencoded-defers.md)
> 该项提议[Proposal: Low-cost defers through inline code, and extra funcdata to manage the panic case](https://go.googlesource.com/proposal/+/refs/heads/master/design/34481-opencoded-defers.md)
开放式延迟调用（**Open-ended defer**）是Go语言中的一种特殊形式的延迟调用。

在普通的延迟调用中，我们使用`defer`关键字将一个函数调用添加到函数返回之前执行。这些延迟调用的数量通常是确定的，并且在函数退出时以反序执行。

而开放式延迟调用是一种更为复杂的情况，在这种情况下，函数可能会在延迟调用的同时启动新的Goroutine，而新的Goroutine也可以注册延迟调用。这导致了在函数退出时可能存在多个活跃的延迟调用。这个过程中，Goroutine和延迟调用之间存在着一种复杂的依赖关系。

为了管理这种复杂性，Go语言中的运行时会为具有开放式延迟调用的函数框架创建一个特殊的 _defer 结构体。这个结构体用于跟踪与开放式延迟调用相关的信息，例如栈帧、函数数据等。

开放式延迟调用通常用于需要在函数返回之前执行清理操作或处理资源释放的复杂逻辑中，例如数据库连接的关闭、文件的关闭等。





## 练习
```golang
package main

import (
	"fmt"
)

func main() {
	A()
	fmt.Println("anonymousVarReturn return value is", anonymousVarReturn())
	fmt.Println("anonymousVarReturn2 return value is", anonymousVarReturn2(1))
	fmt.Println("anonymousVarReturn3 return value is", anonymousVarReturn3(1))
	fmt.Println("namedVarReturn4 return value is", namedVarReturn4())
	fmt.Println("namedVarReturn5 return value is", namedVarReturn5())
	namedVarReturn6()
}

func A1(a int){
	fmt.Println(a)
}

func A(){
	a,b := 1,2
	defer A1(a)

	a = a + b
	fmt.Println(a,b)
}

func anonymousVarReturn() int {
	var i = 0
	defer func() {
		i++
		fmt.Println("anonymousVarReturn defer, i is ", i)
	}()
	return 0
}

func anonymousVarReturn2(i int) int {
	defer func() {
		i++
		fmt.Println("anonymousVarReturn2 defer, i is", i)
	}()
	return i
}

func anonymousVarReturn3(i int) int {
	defer func(i int) {
		i++
		fmt.Println("anonymousVarReturn3 defer, i is", i)
	}(i)
	return i
}

func namedVarReturn4() (i int){
	defer func(i *int) {
		*i++
		fmt.Println("namedVarReturn4 defer, i is", *i)
	}(&i)
	return 1
}


func namedVarReturn5() (i int) {
	defer func(i *int) {
		defer func(i *int){
			*i++
		}(i)
		fmt.Println("namedVarReturn5 defer, i is", *i)
	}(&i)
	return 1
}

func namedVarReturn6() {
	defer func(){
		defer func(){
			fmt.Println("call inside defer func1.1")
		}()
		defer func(){
			fmt.Println("call inside defer func1.2")
		}()
		fmt.Println("call outside defer func1")
	}()
	defer func(){
		defer func(){
			fmt.Println("call inside defer func2")
		}()
		fmt.Println("call outside defer func2")
	}()
}
```


# 参考
 