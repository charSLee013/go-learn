我在V2EX论坛上看到有人问到了几个非常关键的Golang的问题，也是曾经我在学习Golang或者是现在对Golang也保有疑问的问题
所以在此记录精选出几个比较关键的问题进行解答，在此记录下解答的过程

## 环境
* Golang: 1.19.10([link](https://github.com/golang/go/archive/refs/tags/go1.19.10.zip))
* Ubuntu: 22.04

---

# 问题列表

## 语言设计相关
1. Go 语言中对象的生命周期是怎么样的，我注意到例如函数内部创建的对象，在函数结束后并未被销毁。
---

> 请查看[生命周期](./Live%20Cycle.md)，或者查看Golang 官方的[内存模型](https://go.dev/ref/mem)

2. Go 语言基础中是否存在与 java 的万物皆对象类似的基础原则，我注意到似乎不是所有东西都是对象，起码 err 不能用反射调查其属性和方法....
---

误论，可以用下面代码来证明

> 实际上可能是操作有误导致，具体可以查看[反射](./Reflect.md)相关知识
比如反射这个`Path.Error`结构体

```golang
f, err := os.Open("nonexists.txt")
if err != nil {
	errorType := reflect.TypeOf(err).Elem()

	// 遍历结构体字段
	fmt.Println("Fields:")
	for i := 0; i < errorType.NumField(); i++ {
		field := errorType.Field(i)
		fmt.Printf("- %s %s\n", field.Name, field.Type)
	}

	// 遍历结构体方法
	fmt.Println("Methods:")
	for i := 0; i < errorType.NumMethod(); i++ {
		method := errorType.Method(i)
		fmt.Printf("- %s %s\n", method.Name, method.Type)
	}
	os.Exit(-1)
}
f.Close()
```
执行后应该打印出以下内容
```bash
root@iZt4neudsfea8pyuih28ydZ:~/go-learn# go run main.go 
Fields:
- Op string
- Path string
- Err error
Methods:
```

3. defer 的概念非常有趣，也很符合 Go 的设计主旨，不知道 Go 语言中是否有类似 Python 中上下文管理器的工具（即实现打开文件时确保其使用后被关闭，上锁时确保使用后会开锁等操作）
---

相比Python的`with`可以在代码块结束后自动执行指定的释放资源操作，`defer`更像是一种延迟执行的函数，而且好处还在于即使发生了`painc`也能正常执行(更多可以参阅[defer 文档](./defer.md))


4. 从原理角度，如何理解 channel 的调用开销。使用 channel 传递数据究竟是一种廉价操作，还是昂贵操作，其究竟是否依赖锁？按我的理解它依赖于事件循环，每次激活后才会唤醒依赖它的协程，应该是无锁的，但是书里写它其实是有锁的，我不是很懂。
5. 如果 channel 有锁，通道通信相较于内存共享的优越性体现在哪里？
---

`channel`的发送/解锁操作是先进行无锁操作(CAS)，如果失败之后才进行有锁操作
而其他比如加入到等待队列，关闭`channel`等操作都是有锁的
使用`channel`传递数据本质上是一个goroutine将数据传递给另一个goroutine，并且期间如果对方的goroutine处于休眠状态还可以唤醒对方，这样做的好处的是避免竞态条件以及饥饿问题
如果有多个goroutine在等待操作，可以将其放到等待队列中而不需*要死循环进行抢锁操*作来获取到临界资源权限
总体上是比基于共享内存来进行通信的方式更加高效和节省内存

具体可以参阅[channel操作文档](./channel.md)


6. 对于 string 的处理方式。我们都知道 string 通常是比看上去更复杂的数据结构，教学视频中看到的所有赋值和参数调用基本都是直接传值，实际情况是否如此，这是否意味着如果不加优化通常效率会很低？
---

Golang只有**值传递**没有引用传递,对于数据结构来讲比如说 map,channel,struct,slice 都是存储在堆上的
对于这些类型来说，赋值和参数调用本质是在栈上新开辟一个内存位置用来指向堆上数据的指针而已

这样做的好处是提高效率尤其是高并发的情况，但是这样也会引起一些隐式问题
比如说slice切片在两个函数之间进行值传递的时候是指向同一块内存区域，但是某一次操作进行扩容操作后
会导致slice指向新的内存地址而不是旧的内存地址
你可以猜猜下面程序运行的结果
```golang
package main

import (
	"fmt"

)

func main() {
	a := make([]int, 1, 1)
	done := make(chan struct{})
	a[0] = 123
	go func(a []int) {
		a[0] = 321
		done<- struct{}{}
	}(a)
	
	<- done
	fmt.Println(a[0])

	go func(a []int){
		a = append(a, 321)
		a[0] = 123
		done<- struct{}{}
	}(a)
	<- done
	fmt.Println(a[0])
}
```

7. Go 语言设计上多大程度上接近底层，（例如自行推算数组第 n 位指针的地址，这种操作是否允许/是否可靠）
---

首先Golang 是高级语言，对于底层的内存管理和指针操作，它提供了较高级别的抽象，例如自动内存分配和垃圾回收机制。
对于推算出数组的第n位指针可以通过 runtime 包来实现但是不推荐，并且也不可靠

8. Go 语言中闭包的概念是如何的？（由于 goroutine 的出现，似乎搞清闭包规则变得很重要）
---

要了解闭包之前，要先了解golang的内存结构。一个变量是可以存储在goroutine的栈上，也可以是存储在堆上并且该goroutine的stack上保留指向heap的指针
当一个闭包函数引用在闭包函数外定义但在闭包函数内被引用的时候，就会造成逃逸
这样子golang就会把该变量分配在堆上，并且在闭包函数内创建一个指向堆的变量,这样做闭包函数也能正确引用对应的值


9. 命令行打印是否是同步阻塞行为（如果用打印输出程序状态，是否需要考虑类似 console.log 的异步输出情况）
---

在 Go 语言中，命令行打印是同步阻塞的行为。当你使用 fmt.Println 或其他打印函数输出内容到标准输出（终端）时，该函数会将内容直接输出到终端，并且会等待输出完成后才会返回。这意味着在打印完成前，程序会被阻塞。

10. Go 事件循环内部提供的 select 是否依赖系统调用？这是不是一种昂贵操作？
---

select 有针对channel操作做针对优化，具体来讲就是
1. 找出所有`channel`操作的`case`分支
2. 给这些`case`分支对应的`channel`进行顺序上锁
3. 乱序访问是否有可以执行的操作
4. 如果有操作或者是非阻塞，则逆序解锁并返回
5. 在阻塞状态下，将自身加入到所有的channel的等待队列中等待唤醒
6. 唤醒之后将其他的`channel`取消等待并执行对应的`case`分支的操作


11. Go 语言是强类型还是弱类型，为什么函数指定返回 int 类型时还可以返回 nil...
吐个槽，panic 和 recover 使用起来还必须限定于当前绑定的事件循环内，让我觉得需要使用这个特性的场景会变得非常难以理解和不可控。。。
---

int 类型没有nil，默认零值是0
因为 panic和recover 是跟goroutine强绑定的，它们依赖于 goroutine 的调用栈信息。
跟其他语言比如Java限定在`try{}catch{}`代码块不同
这样做的好处是单个goroutine的崩溃不会影响到其他goroutine的运行，并且还能将崩溃的原因限定到goroutine中
可以确保异常处理逻辑的可控性和一致性。它避免了多个 goroutine 之间的状态混乱和错误处理的不确定性

在编写代码时，建议在合适的地方使用恰当的错误处理方式，避免过度依赖 panic 和 recover。只有在确实需要中断当前执行流程或进行特殊处理时，才使用 panic 和 recover。


## 多线程调度相关

1. 多线程竞争资源相关，读书注意到 Go 有提供信号量的概念，请问有与自旋锁对标的东西吗？
2. Go 的调度模型下，单个协程应该是很省的，但是如果我有一万个协程同时对一个 map 进行交互，此种情况下应该如何进行优化？（或者说 Go 应对此种场景时也并无特殊优势?）

## 最佳实践相关
1. 通常情况下，Go 语言调查未知对象内部属性和方法的最佳实践是什么？
2. Go 语言中代码计时的最佳实践？（例如我想对比两种不同算法的 Go 运行时间，通常在各语言里想要准确的计算运行时间都有些坑）
3. 使用 interface{}当做万能指针（例如实际应用场景中使用万能指针在数组中储存不同类型的对象引用）实践中是否有哪些坑？
4. 常见数据结构中，除了 vector 和 map 外，set 、deque 、list 这些有什么官方实现吗？（或者最佳实践）




# 参考
---

[Gopher Academy](https://www.youtube.com/@GopherAcademy/videos)