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
goos: linux
goarch: amd64
BenchmarkDefer-2        20000000                58.2 ns/op
PASS
ok      command-line-arguments  1.237s
```

### go-1.13

我们再来看下**go1.13**下展开的伪代码
```golang
func A(){
	// create strcut and saved to stack
	var d struct {
		runtime._defer
		i int
	}
	d.size = 0
	d.fn = B
	d.i = 10
	r := runtime.deferprocStack(&d._defer)

	// code to do something
	runtime.deferreturn()
	return
}
```
通过在编译阶段，在函数内增加`d strct`结构体的局部变量，将`defer`信息保存在当前函数栈帧的局部变量区域，再通过`deferprocStack`把栈上这个`_defer`结构体注册到`g._defer`链表中

go1.13的优化主要是减少`defer`信息的堆分配，之所以是减少了，像下面这种在`for`循环里面注册`defer`
```golang
for i:=0;i<n;i++{
	defer B(i)
}
```

或者隐式循环
```golang
again:
	defer B()
	if i <n {
		n++
		goto again
	}
```
依然需要使用经典处理方式--在堆上分配`defer`信息。为了区分在是否在堆上分配的`defer`，在go1.13中为`_defer`结构体新增了一个字段，具体如下所示或者直接[点击查看](https://github.com/golang/go/blob/2bc8d90fa21e9547aeb0f0ae775107dc8e05dc0a/src/runtime/runtime2.go#L784)源代码

```golang
type _defer struct {
	...
	heap    bool //用于标识是否为堆分配
	...
}
```
在栈上分配的情况如图所示
![go1.13 defer](./images/go1.13%20defer.png)

再来看下性能基准测试的结果
```
goos: linux
goarch: amd64
BenchmarkDefer-2        27385267                44.1 ns/op
PASS
ok      command-line-arguments  1.257s
```
相比之后并没有官方吹的提升30%那么猛，但是也足够了

### go-1.14
go1.14直接就对`defer`进行了大刀阔斧的优化了，首先来个示例代码
```golang
func A(i int){
	defer A1(i, 2*i)

	// code to something

	if (i>1) {
		defer A2("hello","world")
	}

	// code to something
	return
}

func A1(a,b int){
	...
}

func A2(m,n string){
	...
}
```

我们首先看第一个`defer`函数，需要传入两个变量，此时golang在编译阶段在函数内插入变量的初始化以备`defer`函数调用  
```golang
var a,b int = i,2*i
```

然后在函数返回之前直接调用`defer`注册的函数--**A1**即可
```golang
A1(a,b)
return
```

省去了构造`defer`以及注册到`g._defer`链表的过程,也同样实现了`defer`函数延迟执行的效果

不过运行时才确定的`defer`就不能这么简单的处理了，比如下面这个
```golang
if (i > 1){
	defer A2()
}
```

为了知道运行时是否要执行这个`defer`函数，Golang用一个标识变量`df`来解决这个问题
```golang
var df byte
```

`df`是一个`byte`类型的变量，大小为**8bit**,其中每一**bit** 控制`defer`函数是否应该执行，整个数据结构图示如下

![open close defer](./images/open%20close%20defer.png)

那么此时只有运行时候才能确定是否要执行的`defer`函数，展开后的伪代码如下
```golang
if (i > 1){
	df |= 2
}
```

然后到了函数返回的时候根据`df`的上每位对应**bit**位来确定时候运行
```golang
if df &2 > 0{
	df = df &^ 2	// 把df对应标识位置设为0，避免重复执行
}
```

此时整个代码的伪代码展开是这样的
```golang
func A(i int){
	var df byte
	var a,b int = i,2*i

	df |= 1		// 设置为1表明要执行第一个defer函数

	//code to do something
	var m,n string = "hello","world"

	if i > 1{
		df |= 2	// 设置为2表明要执行第二个defer函数
	}

	// code to do something
	if df&2 > 0{
		df = df&^2
		A2(m,n)
	}

	if df&1 > 0{
		df = df &^1
		A1(a,b)
	}

	return
}
```

可以到优化的地方在于通过在编译阶段插入代码，把`defer`函数的执行逻辑展开在所属函数内,从而避免创建`_defer`结构体,也不需要注册到`defer`链表中

但是跟go1.13版本一样，遇到循环只能回退到经典模式--在堆上创建`defer`信息并且链接到`g._defer`链表上

再来看下性能基准测试的结果
```
goos: linux
goarch: amd64
BenchmarkDefer-2        175151754                6.37 ns/op
PASS
ok      command-line-arguments  1.813s
```
优化性能显著提高

### 代价

想象一下，如果在函数执行过程发生了`panic`了，在编译阶段里面展开的`open-close defer`会怎么办？

```golang
	painc("painc for error") // 比如这里发生了painc
	// 这里已经无法执行了
	if df&2 > 0{
		df = df&^2
		A2(m,n)
	}
	...
```

这个时候就需要记录下未注册的`defer`信息，所以1.14版本在`_defer`结构体上新增加了几个[字段](https://github.com/golang/go/blob/5cf057ddedfbb149b71c85ec86050431dd6b2d9d/src/runtime/runtime2.go#L865)
```golang
type _defer struct {
	...
	openDefer bool	// 标识是否为openDefer类型

	// 如果openDefer为true,下面的字段记录与拥有内联defer的栈帧
	// 和相关函数有关的值。上面的sp将是栈帧的sp,pc将是
	// 函数内deferreturn调用的地址。
	fd   unsafe.Pointer  // 与栈帧相关函数的funcdata
	varp uintptr        // 栈帧的varp的值
  // framepc是与栈帧相关的当前pc。与上面的sp(栈帧的sp)
  // 一起,framepc/sp可以作为pc/sp对,通过gentraceback()
  // 继续进行堆栈追踪。
	framepc uintptr
}
```

借助这些信息可以找到未注册到链表的`defer`函数


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
 