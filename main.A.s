TEXT main.A1(SB) /root/go-learn/main.go
func A1(a int){
  0x4818c0		493b6610		CMPQ 0x10(R14), SP	
  0x4818c4		0f8699000000		JBE 0x481963		
  0x4818ca		4883ec58		SUBQ $0x58, SP		
  0x4818ce		48896c2450		MOVQ BP, 0x50(SP)	
  0x4818d3		488d6c2450		LEAQ 0x50(SP), BP	
  0x4818d8		4889442460		MOVQ AX, 0x60(SP)	
	fmt.Println(a)
  0x4818dd		440f117c2428		MOVUPS X15, 0x28(SP)			
  0x4818e3		488d4c2428		LEAQ 0x28(SP), CX			
  0x4818e8		48894c2420		MOVQ CX, 0x20(SP)			
  0x4818ed		488b442460		MOVQ 0x60(SP), AX			
  0x4818f2		e8c982f8ff		CALL runtime.convT64(SB)		
  0x4818f7		4889442418		MOVQ AX, 0x18(SP)			
  0x4818fc		488b7c2420		MOVQ 0x20(SP), DI			
  0x481901		8407			TESTB AL, 0(DI)				
  0x481903		488d0d36750000		LEAQ 0x7536(IP), CX			
  0x48190a		48890f			MOVQ CX, 0(DI)				
  0x48190d		488d4f08		LEAQ 0x8(DI), CX			
  0x481911		833d98970d0000		CMPL $0x0, runtime.writeBarrier(SB)	
  0x481918		7402			JE 0x48191c				
  0x48191a		eb06			JMP 0x481922				
  0x48191c		48894708		MOVQ AX, 0x8(DI)			
  0x481920		eb0a			JMP 0x48192c				
  0x481922		4889cf			MOVQ CX, DI				
  0x481925		e896c3fdff		CALL runtime.gcWriteBarrier(SB)		
  0x48192a		eb00			JMP 0x48192c				
  0x48192c		488b442420		MOVQ 0x20(SP), AX			
  0x481931		8400			TESTB AL, 0(AX)				
  0x481933		eb00			JMP 0x481935				
  0x481935		4889442438		MOVQ AX, 0x38(SP)			
  0x48193a		48c744244001000000	MOVQ $0x1, 0x40(SP)			
  0x481943		48c744244801000000	MOVQ $0x1, 0x48(SP)			
  0x48194c		bb01000000		MOVL $0x1, BX				
  0x481951		4889d9			MOVQ BX, CX				
  0x481954		e827acffff		CALL fmt.Println(SB)			
}
  0x481959		488b6c2450		MOVQ 0x50(SP), BP	
  0x48195e		4883c458		ADDQ $0x58, SP		
  0x481962		c3			RET			
func A1(a int){
  0x481963		4889442408		MOVQ AX, 0x8(SP)			
  0x481968		e893a3fdff		CALL runtime.morestack_noctxt.abi0(SB)	
  0x48196d		488b442408		MOVQ 0x8(SP), AX			
  0x481972		e949ffffff		JMP main.A1(SB)				

TEXT main.A(SB) /root/go-learn/main.go
func A(){
  0x481980		4c8d642498		LEAQ -0x68(SP), R12	
  0x481985		4d3b6610		CMPQ 0x10(R14), R12	
  0x481989		0f86a0010000		JBE 0x481b2f		
  0x48198f		4881ece8000000		SUBQ $0xe8, SP		
  0x481996		4889ac24e0000000	MOVQ BP, 0xe0(SP)	
  0x48199e		488dac24e0000000	LEAQ 0xe0(SP), BP	
	a,b := 1,2
  0x4819a6		48c744242001000000	MOVQ $0x1, 0x20(SP)	
  0x4819af		48c744241802000000	MOVQ $0x2, 0x18(SP)	
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
  0x481a02		0f8512010000		JNE 0x481b1a			
  0x481a08		eb00			JMP 0x481a0a			
	a = a + b
  0x481a0a		488b4c2420		MOVQ 0x20(SP), CX	
  0x481a0f		48034c2418		ADDQ 0x18(SP), CX	
  0x481a14		48894c2420		MOVQ CX, 0x20(SP)	
	fmt.Println(a,b)
  0x481a19		440f11bc24c0000000		MOVUPS X15, 0xc0(SP)			
  0x481a22		440f11bc24d0000000		MOVUPS X15, 0xd0(SP)			
  0x481a2b		488d8c24c0000000		LEAQ 0xc0(SP), CX			
  0x481a33		48898c2498000000		MOVQ CX, 0x98(SP)			
  0x481a3b		488b442420			MOVQ 0x20(SP), AX			
  0x481a40		e87b81f8ff			CALL runtime.convT64(SB)		
  0x481a45		4889842490000000		MOVQ AX, 0x90(SP)			
  0x481a4d		488bbc2498000000		MOVQ 0x98(SP), DI			
  0x481a55		8407				TESTB AL, 0(DI)				
  0x481a57		488d0de2730000			LEAQ 0x73e2(IP), CX			
  0x481a5e		48890f				MOVQ CX, 0(DI)				
  0x481a61		488d4f08			LEAQ 0x8(DI), CX			
  0x481a65		833d44960d0000			CMPL $0x0, runtime.writeBarrier(SB)	// 比较runtime.writeBarrier这个函数的地址是否为0
  0x481a6c		7402				JE 0x481a70				
  0x481a6e		eb06				JMP 0x481a76				// 如果不为0,就会跳转到实际的写屏障函数
  0x481a70		48894708			MOVQ AX, 0x8(DI)			
  0x481a74		eb0c				JMP 0x481a82				
  0x481a76		4889cf				MOVQ CX, DI				// 也就是这里，执行写屏障
  0x481a79		e842c2fdff			CALL runtime.gcWriteBarrier(SB)		
  0x481a7e		6690				NOPW					
  0x481a80		eb00				JMP 0x481a82				
; 那么为什么这里会插入写屏障呢?
; 下面有一段代码是将b变量的值保存到堆栈上:
  0x481a82		488b442418			MOVQ 0x18(SP), AX			
; 函数参数和栈中的局部变量在存储上统一使用64位宽度。
; 即使int类型在32位系统上是一个32位的值,但为了存储上的统一,在传递和栈内存中也会扩展到64位。
; 所以下面将int类型的b变量转化成64位
  0x481a87		e83481f8ff			CALL runtime.convT64(SB)
  0x481a8c		4889842488000000		MOVQ AX, 0x88(SP)			
  0x481a94		488bbc2498000000		MOVQ 0x98(SP), DI			
  0x481a9c		8407				TESTB AL, 0(DI)				
  0x481a9e		488d0d9b730000			LEAQ 0x739b(IP), CX			
  0x481aa5		48894f10			MOVQ CX, 0x10(DI)			
  0x481aa9		488d4f18			LEAQ 0x18(DI), CX			
  0x481aad		833dfc950d0000			CMPL $0x0, runtime.writeBarrier(SB)	
  0x481ab4		7402				JE 0x481ab8				
  0x481ab6		eb06				JMP 0x481abe				
  0x481ab8		48894718			MOVQ AX, 0x18(DI)			
  0x481abc		eb0a				JMP 0x481ac8				
  0x481abe		4889cf				MOVQ CX, DI				
  0x481ac1		e8fac1fdff			CALL runtime.gcWriteBarrier(SB)		
  0x481ac6		eb00				JMP 0x481ac8				
  0x481ac8		488b842498000000		MOVQ 0x98(SP), AX			
  0x481ad0		8400				TESTB AL, 0(AX)				
  0x481ad2		eb00				JMP 0x481ad4				
  0x481ad4		48898424a8000000		MOVQ AX, 0xa8(SP)			
  0x481adc		48c78424b000000002000000	MOVQ $0x2, 0xb0(SP)			
  0x481ae8		48c78424b800000002000000	MOVQ $0x2, 0xb8(SP)			
  0x481af4		bb02000000			MOVL $0x2, BX				
  0x481af9		4889d9				MOVQ BX, CX				
  0x481afc		0f1f4000			NOPL 0(AX)				
  0x481b00		e87baaffff			CALL fmt.Println(SB)			
}
  0x481b05		e856ddfaff		CALL runtime.deferreturn(SB)	
  0x481b0a		488bac24e0000000	MOVQ 0xe0(SP), BP		
  0x481b12		4881c4e8000000		ADDQ $0xe8, SP			
  0x481b19		c3			RET				
	defer A1(a)
  0x481b1a		e841ddfaff		CALL runtime.deferreturn(SB)	
  0x481b1f		488bac24e0000000	MOVQ 0xe0(SP), BP		
  0x481b27		4881c4e8000000		ADDQ $0xe8, SP			
  0x481b2e		c3			RET				
func A(){
  0x481b2f		e8cca1fdff		CALL runtime.morestack_noctxt.abi0(SB)	
  0x481b34		e947feffff		JMP main.A(SB)				

TEXT main.A.func1(SB) /root/go-learn/main.go
	defer A1(a)
  0x481b40		493b6610		CMPQ 0x10(R14), SP		
  0x481b44		762f			JBE 0x481b75			
  0x481b46		4883ec18		SUBQ $0x18, SP			
  0x481b4a		48896c2410		MOVQ BP, 0x10(SP)		
  0x481b4f		488d6c2410		LEAQ 0x10(SP), BP		
  0x481b54		4d8b6620		MOVQ 0x20(R14), R12		
  0x481b58		4d85e4			TESTQ R12, R12			
  0x481b5b		751f			JNE 0x481b7c			
  0x481b5d		488b4208		MOVQ 0x8(DX), AX		
  0x481b61		4889442408		MOVQ AX, 0x8(SP)		
  0x481b66		e855fdffff		CALL main.A1(SB)		
  0x481b6b		488b6c2410		MOVQ 0x10(SP), BP		
  0x481b70		4883c418		ADDQ $0x18, SP			
  0x481b74		c3			RET				
  0x481b75		e8e6a0fdff		CALL runtime.morestack.abi0(SB)	
  0x481b7a		ebc4			JMP main.A.func1(SB)		
  0x481b7c		4c8d6c2420		LEAQ 0x20(SP), R13		
  0x481b81		4d392c24		CMPQ R13, 0(R12)		
  0x481b85		75d6			JNE 0x481b5d			
  0x481b87		49892424		MOVQ SP, 0(R12)			
  0x481b8b		ebd0			JMP 0x481b5d			
