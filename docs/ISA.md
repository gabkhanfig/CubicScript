# Instruction Set Architecture

Instructions are variable width, but generally 4 bytes in size.
All 4 byte bytecodes are in one of 3 patterns, where I is the 1 byte instructions
> I A B C A = 1 byte operand, B = 1 byte operand, C = 1 byte operand
> I A B A   = 1 byte operand, B = 2 byte operand
> I A       = 3 byte operand

## General Instructions

- [0x00] nop Do nothing
- [0x01] exit End of script
- [0x02] ret Return from the function
- [0x03] jmp (dst) Uncomditionally jump to dst
- [0x04] jz (dst, src) Jump to dst
- [0x05] jnz (dst, src) Jump to dst if the value at src is not zero
- [0x06] mov (dst, src) Copy value at register src to register dst
- [0x07] load (dst, src) Copy the value at the address held at src into dst
- [0x08] loado (dst, src, offset) Copy the value at the address held by src + sign extended offset into dst.
- [0x08] loadi (dst, immediate) Copy the immediate 16 bit sign extended value into dst
- [0x09] loadil (dst, immediate) (12 byte op length) Copy the long immeidate 64 bit value into dst
- [0x0A] store (dst, src) Copy value at src into the address held at dst
- [0x0B] storeo (dst, src, offset) Copy value at src into the address held at dst by sign extended offset
- [0x0B] push (src) Push value at src register to the top of the stack, incrementing the stack pointer
- [0x0C] pop (dst) Pop the value at the top of the stack into dst, decrementing the stack pointer
