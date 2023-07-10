# 生命周期

## 注意

```
The terms "stack" and "heap" do not appear in the Go language specification. The Go declaration syntax does not specifically mention stack or heap allocation .
```

Golang 官方[语言规范](https://go.dev/ref/spec)并没有明确声明"堆"和"栈"这两个术语，是为了避免跟传统的进程/线程模型的内存分配搞混。

你可以理解为Golang中的**栈**对应的是无需GC回收私有的内存，**堆**则是被GC回收并且可以共享的内存。(这个说法仅用于理解并不完全正确)

而且跟其他语言不同的在于，即使你没有显式声明对象存在堆上，Golang 会通过逃逸分析确定该对象是否需要被"逃逸"到堆上创建


## 逃逸分析(Escape Analysis)

---

### 逃逸分析的原理
逃逸分析的目标是确定一个变量的生命周期是否会超出当前函数的作用域。如果一个变量逃逸到了函数外部，意味着它的生命周期需要持续到整个程序运行结束，此时编译器会将其分配在堆上。相反，如果一个变量仅在函数内部使用，那么它可以被分配在栈上，这样就能够避免堆上内存分配和垃圾回收的开销。

逃逸分析的过程可以简单描述为以下几个步骤：

* 遍历抽象语法树（AST）：编译器首先会遍历抽象语法树，确定每个变量的作用域和使用方式。
* 分析变量的引用关系：编译器会分析变量之间的引用关系，判断是否有逃逸情况存在。
* 决策变量的分配位置：根据变量的逃逸情况，编译器会决定将变量分配在栈上还是堆上。

值得注意的是，逃逸分析并不是精确的，它只是通过静态分析来猜测变量是否会逃逸，并进行相应的优化。在某些情况下，编译器可能会做出错误的猜测，导致变量被错误地分配到了栈或堆上。


### 如何使用逃逸分析
以下是一些常用的逃逸分析相关的编译器标志：

* `-gcflags="-m"`：启用逃逸分析，并打印逃逸分析的详细信息。

* `-gcflags="-m -l"`：启用逃逸分析，并打印逃逸分析的详细信息，同时禁用内联优化。

* `-gcflags="-m -m"`: 打印逃逸分析的详细信息和内存分配的信息。
    提供了有关内部分配器行为的更多细节，例如内存块的分割和释放。


举个例子说明
逃逸分析的情况有很多种。以下是一些常见情况的示例，涵盖了可能的全部可能性，并附有相应的注释：

```go
package main

type S struct {
	name string
}

func escapeToHeap() *S {
	s := S{name: "John"} // 变量s会逃逸到堆上，因为它作为函数返回值被外部引用
	return &s
}

func noEscape() S {
	s := S{name: "Alice"} // 变量s不会逃逸，因为它只在函数内部使用，并且作为函数返回值被拷贝到调用方的栈帧中
	return s
}

func escapeToHeapSlice() []*S {
	slice := make([]*S, 3) // 切片slice会逃逸到堆上，因为它是动态分配的，其地址会被保存在函数返回值中
	for i := 0; i < 3; i++ {
		slice[i] = &S{} // 切片中的每个元素都是指向堆上新创建的S对象的指针
	}
	return slice
}

func noEscapeArray() [3]S {
	array := [3]S{} // 数组array不会逃逸，因为它是在函数栈帧上分配的，并且作为函数返回值被拷贝到调用方的栈帧中
	for i := 0; i < 3; i++ {
		array[i].name = "Bob" // 修改数组元素的值不会导致逃逸
	}
	return array
}

func main() {
	escapeToHeap()
	noEscape()
	escapeToHeapSlice()
	noEscapeArray()
}
```

在上面的示例中，我们使用了不同的数据结构和分配方式来演示逃逸分析的不同情况：

- `escapeToHeap`函数中，变量`s`会逃逸到堆上，因为它作为函数返回值被外部引用。
- `noEscape`函数中，变量`s`不会逃逸，因为它只在函数内部使用，并且作为函数返回值被拷贝到调用方的栈帧中。
- `escapeToHeapSlice`函数中，切片`slice`会逃逸到堆上，因为它是动态分配的，其地址会被保存在函数返回值中。
- `noEscapeArray`函数中，数组`array`不会逃逸，因为它是在函数栈帧上分配的，并且作为函数返回值被拷贝到调用方的栈帧中。

我们使用逃逸分析是否符合判断

```bash
> go build -gcflags="-m -l"

./main.go:8:2: moved to heap: s
./main.go:18:15: make([]*S, 3) escapes to heap
./main.go:20:14: &S{} escapes to heap
```

### for 陷阱
来看下面代码，猜打印出来的结果是什么

```golang
package main
import "fmt"

type student struct {
    Name string
    Age  int
}

func pase_student() {
    m := make(map[string]*student)
    stus := []student{
        {Name: "zhou", Age: 24},
        {Name: "li", Age: 23},
        {Name: "wang", Age: 22},
    }

    for _,stu := range stus {
        m[stu.Name] = &stu
    }


	for k,v := range m{
		fmt.Printf("%v = %v\n", k,v.Age);
	}
}

func main(){
	pase_student()
}
```

如果你答案是
```
zhou = &{zhou 24}
li = &{li 23}
wang = &{wang 22}
```
那么恭喜你，完全错误，具体原因是由于 `m[stu.Name] = &stu` 的赋值操作在每次循环时都是将 `&stu` 赋给 `m[stu.Name]`，而 `&stu` 是指向 `stu` 的指针，而 `stu` 的内存地址在第一次创建的时候就已经决定了。
因此，当循环结束后，`m` 中的所有值都指向了同一个地址，即最后一次迭代的 `stu` 的地址，导致打印出来的内容中的值都一样，并且是最后一个学生的信息。

所以，代码打印的内容是：

```
zhou = &{Name:wang Age:22}
li = &{Name:wang Age:22}
wang = &{Name:wang Age:22}
```

即键为学生的姓名，值为最后一个学生的指针。

其实我们通过逃逸分析也能知晓这一点
```bash
./main.go:16:12: moved to heap: stu
./main.go:10:14: make(map[string]*student) does not escape
./main.go:11:22: []student{...} does not escape
./main.go:20:13: ... argument does not escape
./main.go:20:14: k escapes to heap
./main.go:20:30: v.Age escapes to heap
```
本来在`for .. in range` 循环作用域内的`stu`被移动到了堆上，这是因为对于 `for .. in range`来说，等效展开如下
```golang
    var stu student
    for idx, _ := range stus {
        stu = stus[idx]
        m[stu.Name] = &stu
    }
```

我们可以发现 `stu` 变量只创建了一次，然后在循环内每次将`stus`对应索引值的值赋值给`stu`，这就导致了在给`m`的指针其实是`stu`的内存位置

既然知道了具体细节，我们就可以将代码改为下面的形式
```golang
    for idx, _ := range stus {
        stu := stus[idx]
        m[stu.Name] = &stu
    }
```
再一次执行和逃逸分析
```bash
$ go run main.go 
li = 23
wang = 22
zhou = 24

$ go build --gcflags="-l -m"
# go-learn
./main.go:19:9: moved to heap: stu
./main.go:10:14: make(map[string]*student) does not escape
./main.go:11:22: []student{...} does not escape
./main.go:27:13: ... argument does not escape
./main.go:27:14: k escapes to heap
./main.go:27:30: v.Age escapes to heap
```


## 闭包
闭包是指一个函数（或方法）和它引用的环境变量组合而成的实体。在Go语言中，当一个函数内部引用了自由变量(在闭包函数外定义但在函数内被引用)时，形成了闭包。
闭包和函数最大的不同在于，当捕捉闭包的时候，它的自由变量会在捕捉时被确定，这样即便**脱离了捕捉时的上下文**，它也能照常运行
闭包在运行时会自动创建一个包含了引用的变量的结构体，并将其分配在堆上。

下面举几个例子来说明闭包的内存分配情况：

### 示例1：
```go
func increment() func() int {
    count := 0
    return func() int {
        count++
        return count
    }
}

func main() {
    counter := increment()
    fmt.Println(counter()) // 输出: 1
    fmt.Println(counter()) // 输出: 2
}
```
 

在这个例子中，`increment` 函数返回了一个匿名函数，该匿名函数引用了外部的 `count` 变量。
我们来进行一次逃逸分析
```bash
./main.go:6:5: moved to heap: count
./main.go:7:12: func literal escapes to heap
./main.go:15:16: ... argument does not escape
./main.go:15:24: counter() escapes to heap
./main.go:16:16: ... argument does not escape
./main.go:16:24: counter() escapes to heap
```
我们看到由于闭包的存在，`count` 变量被分配在堆上，而不是栈上。同样地，闭包函数本身也发生了逃逸，被分配到了堆上。这是因为闭包函数被返回给了外部调用者，并且可能在 `main` 函数中继续被调用。为了确保闭包函数在 `main` 函数执行完毕后依然有效，编译器将其分配到堆上，以延长其生命周期。
值得注意的是，调用闭包函数的返回值 `counter()` 并没有发生逃逸，它并没有被分配到堆上，而是仍然在栈上分配。



### 示例2：
```go
type Person struct {
    name string
}

func getNameFunc(p *Person) func() string {
    return func() string {
        return p.name
    }
}

func main() {
    person := &Person{"Alice"}
    getName := getNameFunc(person)
    fmt.Println(getName()) // 输出: "Alice"
}
```

按照惯例来个逃逸分析:
```bash
./main.go:10:18: leaking param: p
./main.go:11:12: func literal escapes to heap
./main.go:17:15: &Person{...} escapes to heap
./main.go:20:16: ... argument does not escape
./main.go:20:24: getName() escapes to heap
```

可以看出，`p` 参数和闭包函数都发生了逃逸，被分配到堆上。

在函数 `getNameFunc` 中，我们返回了一个闭包函数，该闭包函数引用了参数 `p`。由于闭包函数可能在 `getNameFunc` 函数执行完毕后仍然存在和被调用，因此编译器将 `p` 参数分配到堆上，以确保闭包函数可以正常访问并使用它。

同样地，闭包函数本身也发生了逃逸，被分配到了堆上。这是因为闭包函数被返回给了外部调用者，并且可能在 `main` 函数中继续被调用。为了确保闭包函数在 `main` 函数执行完毕后依然有效，编译器将其分配到堆上，以延长其生命周期。

尽管 `person` 是通过` &Person{"Alice"}` 创建的，本质上是一个指向结构体的指针，但逃逸分析将其视为整个 `Person` 结构体发生了逃逸。这是因为 `getNameFunc` 函数返回的闭包函数引用了 `person` 变量，并且可能在 `main` 函数执行完毕后继续被调用。为了确保闭包函数可以正常访问 `person` 变量，编译器将 `person` 分配到了堆上，以延长其生命周期。


这些例子说明，在闭包中，如果函数内部引用了外部的变量，那么这些被引用的变量会被分配在堆上，而不是栈上。这样可以确保闭包函数在其生命周期内可以正常访问这些外部变量，而不会因为栈上的变量释放导致错误。



---
# 参考

[Stack vs heap allocation of structs in Go, and how they relate to garbage collection](https://stackoverflow.com/questions/10866195/stack-vs-heap-allocation-of-structs-in-go-and-how-they-relate-to-garbage-collec)