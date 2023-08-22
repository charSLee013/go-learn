我在V2EX论坛上看到有人问到了几个非常关键的Golang的问题，也是曾经我在学习Golang或者是现在对Golang也保有疑问的问题
所以在此记录精选出几个比较关键的问题进行解答，在此记录下解答的过程

## 环境
* Golang: 1.19.10([link](https://github.com/golang/go/archive/refs/tags/go1.19.10.zip))
* Ubuntu: 22.04

---

# 问题列表

## 语言设计相关
1. Go 语言中对象的生命周期是怎么样的，我注意到例如函数内部创建的对象，在函数结束后并未被销毁。

> 请查看[生命周期](./Live%20Cycle.md)，或者查看Golang 官方的[内存模型](https://go.dev/ref/mem)

2. Go 语言基础中是否存在与 java 的万物皆对象类似的基础原则，我注意到似乎不是所有东西都是对象，起码 err 不能用反射调查其属性和方法....
误论，可以用下面代码来

> 实际上可能是操作有误导致，具体可以查血[反射](./Reflect.md)相关知识
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

相比Python的`with`可以在代码块结束后自动执行指定的释放资源操作，`defer`更像是一种延迟执行的函数，而且好处还在于即使发生了`painc`也能正常执行(更多可以参阅[defer 文档](./defer.md))


4. 从原理角度，如何理解 channel 的调用开销。使用 channel 传递数据究竟是一种廉价操作，还是昂贵操作，其究竟是否依赖锁？按我的理解它依赖于事件循环，每次激活后才会唤醒依赖它的协程，应该是无锁的，但是书里写它其实是有锁的，我不是很懂。
5. 如果 channel 有锁，通道通信相较于内存共享的优越性体现在哪里？



6. 对于 string 的处理方式。我们都知道 string 通常是比看上去更复杂的数据结构，教学视频中看到的所有赋值和参数调用基本都是直接传值，实际情况是否如此，这是否意味着如果不加优化通常效率会很低？
7. Go 语言设计上多大程度上接近底层，（例如自行推算数组第 n 位指针的地址，这种操作是否允许/是否可靠）
8. Go 语言中闭包的概念是如何的？（由于 goroutine 的出现，似乎搞清闭包规则变得很重要）
9. 命令行打印是否是同步阻塞行为（如果用打印输出程序状态，是否需要考虑类似 console.log 的异步输出情况）
10. Go 事件循环内部提供的 select 是否依赖系统调用？这是不是一种昂贵操作？
11. Go 语言是强类型还是弱类型，为什么函数指定返回 int 类型时还可以返回 nil...
吐个槽，panic 和 recover 使用起来还必须限定于当前绑定的事件循环内，让我觉得需要使用这个特性的场景会变得非常难以理解和不可控。。。

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