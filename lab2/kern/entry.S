/* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>

# Shift Right Logical 
#define SRL(val, shamt)		(((val) >> (shamt)) & ~(-1 << (32 - (shamt))))


# ##################################################################
# The kernel (this code) is linked at address ~(KERNBASE + 1 Meg), 
# but the bootloader loads it at address ~1 Meg.
#	
# RELOC(x) maps a symbol x from its link address to its actual
# location in physical memory (its load address).	 
#
# 内核代码被link脚本链接在 (KERNBASE + 1 Meg)的虚拟段内存地址
# 但是booter实际加载内核在1M物理内存地址处
# 下面的RELOC宏就是将这个段虚拟地址还原为物理地址
# ##################################################################

#define	RELOC(x) ((x) - KERNBASE)

#define MULTIBOOT_HEADER_MAGIC (0x1BADB002)
#define MULTIBOOT_HEADER_FLAGS (0)
#define CHECKSUM (-(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS))

# ##################################################################
# entry point
# 入口及多重引导头
# ##################################################################
.text
# The Multiboot header
.align 4
.long MULTIBOOT_HEADER_MAGIC
.long MULTIBOOT_HEADER_FLAGS
.long CHECKSUM

# '_start' specifies the ELF entry point.  Since we haven't set up
# virtual memory when the bootloader enters this code, we need the
# bootloader to jump to the *physical* address of the entry point.
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	movw	$0x1234,0x472			# warm boot

	# We haven't set up virtual memory yet, so we're running from
	# the physical address the boot loader loaded the kernel at: 1MB
	# (plus a few bytes).  However, the C code is linked to run at
	# KERNBASE+1MB.  Hence, we set up a trivial page directory that
	# translates virtual addresses [KERNBASE, KERNBASE+4MB) to
	# physical addresses [0, 4MB).  This 4MB region will be
	# sufficient until we set up our real page table in mem_init
	# in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.

	# 下面加载内核初始化时定义的临时 4M 虚拟页目录，由RELOC还原出真实物理地址
	# 1. 物理地址存入cr3, 2. 打开cr0的页控制位
	movl	$(RELOC(entry_pgdir)), %eax
	movl	%eax, %cr3
	# Turn on paging.
	movl	%cr0, %eax
	orl		$(CR0_PE|CR0_PG|CR0_WP), %eax
	movl	%eax, %cr0

	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	# 已开启页访问，下面及c语言中已是虚拟页计址，需要跳转过去
	mov	$relocated, %eax
	jmp	*%eax

# 此处已开始使用虚拟页地址计址
relocated:
	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	# 初始化页帧寄存器
	movl	$0x0,%ebp			# nuke frame pointer
	# Set the stack pointer
	# 初始化栈指针寄存器
	movl	$(bootstacktop),%esp
	# now to C code
	# 控制权转移到c语言
	call	i386_init

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin


.data
# ##################################################################
# boot stack
# ##################################################################
	.p2align	PGSHIFT		# 强制页对齐, PGSHIFT = 12, 2^12 = 4k = PGSIZE
	.globl		bootstack
bootstack:
	.space		KSTKSIZE	# 8*PGSIZE, 内核初始栈8页大小
	.globl		bootstacktop   
bootstacktop:

