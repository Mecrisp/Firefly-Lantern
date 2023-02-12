
.option norelax
.option rvc

.section mecrisp, "awx" # Everything is writeable and executable

.global _start
_start:

# -----------------------------------------------------------------------------
#  Prepare 1920x1080x32bpp framebuffer
# -----------------------------------------------------------------------------

framebuffer_open:
   li x10, -100                # Directory: AT_FDCWD
   la x11, device              # Device to open
   li x12, 2                   # O_RDWR
   li x17, 56                  # "openat"
   ecall                       # open("/dev/fb0", O_RDWR)
framebuffer_mmap:
   mv x14, x10                 # --> File descriptor
   la x10, 0                   # Device to open
   li x11, 1920 * 1080 * 4     # Length
   li x12, 3                   # PROT_READ | PROT_WRITE
   li x13, 1                   # MAP_SHARED
   #  x14                      # File descriptor
   li x15, 0                   # Offset
   li x17, 222                 # "mmap"
   ecall                       # mmap2(NULL, Length, PROT_READ|PROT_WRITE, MAP_SHARED, FD, 0)

   # Mapped address of framebuffer is now in x10.

   # See https://jborza.com/post/2021-05-11-riscv-linux-sysc.jals/
   # for sysc.jal numbers

   mv x3, x10

   j oscillator_initialisation # Skip DAC initialisations

.align 8, 0

# -----------------------------------------------------------------------------

#
#    Firefly Lantern - Fairy lights for Lovebyte 2023
#    Copyright (C) 2023  Matthias Koch
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

.option norelax
.option rvc

# -----------------------------------------------------------------------------
#  Memory map
# -----------------------------------------------------------------------------

.equ memory, 0x20000000 # 32 kb RAM from 0x20000000 to 0x20008000

# ----------------------------------------------------------------------------
#  Define selectable properties
# ----------------------------------------------------------------------------

.equ LOGFILAMENTS, 5  # Number of filaments
.equ LOGLENGTH,    7  # Length of tails

.equ FOLLOW,   30   # Step size for following
.equ EXPAND,   16   # Step size to expand filaments

.equ FIXPOINT, 10   # Number of fractional bits
.equ EULER,     5   # Euler method step size for differential equation integration

.equ OSCX, 0 # -31  # Initial coordinates for the chaotic oscillator
.equ OSCY, -16
.equ OSCZ,  -1

.equ LOGDESTINATIONDURATION, 6 # Change destination after these frames

# ----------------------------------------------------------------------------
#  Derived and fixed properties
# ----------------------------------------------------------------------------

.equ FILAMENTS,    (1<<LOGFILAMENTS)

.equ LENGTH,       (1<<LOGLENGTH)
.equ LENGTHMASK,  ((1<<LOGLENGTH)-1)

.equ LOGDATASIZE, 3
.equ DATASIZE,     (1<<LOGDATASIZE)

# -----------------------------------------------------------------------------
#  Peripheral IO registers
# -----------------------------------------------------------------------------

  .equ GPIOA_BASE,   0x40010800
  .equ GPIOA_CTL0,        0x000

  .equ RCU_BASE,     0x40021000
  .equ RCU_CTL,           0x000
  .equ RCU_CFG0,          0x004
  .equ RCU_APB2EN,        0x018
  .equ RCU_APB1EN,        0x01C

  .equ DAC_BASE,     0x40007000
  .equ DAC_CTL,           0x400
  .equ DACC_R12DH,        0x420

# -----------------------------------------------------------------------------
Reset:
# -----------------------------------------------------------------------------

  li x14, RCU_BASE
  li x3,  DAC_BASE

  li x15, -1
  sw x15, RCU_APB2EN(x14) # Enable PORTA and everything else
  sw x15, RCU_APB1EN(x14) # Enable DAC and everything else

  li x12, GPIOA_BASE+0x800       # Split address for shorter opcodes
  sw zero, GPIOA_CTL0-0x800(x12) # Switch DAC pins PA4 and PA5 to analog mode (PA0 to PA7, indeed)

  li x15, 0x00010001      # Enable both DAC channels by setting DEN0 and DEN1
  sw x15, DAC_CTL(x3)

# -----------------------------------------------------------------------------
oscillator_initialisation:

  li x24, OSCX
  li x25, OSCY
  li x26, OSCZ

  li x12, 0 # Frame counter. Initialise memory when zero.

# -----------------------------------------------------------------------------
#  Notes on register usage while in animation loop:
#
#   x2: Particle loop counter
#   x3: Constant DAC_BASE
#
#   x7: Step size for moves
#   x8: Scratch
#   x9: Scratch
#  x10: Particle position, x-component
#  x11: Particle position, y-component
#  x12: Frame counter
#  x13: Destination, x-component and scratch
#  x14: Destination, y-component and scratch
#  x15: Scratch
#
#  x22: Current pseudorandom coordinate, x-component
#  x23: Current pseudorandom coordinate, y-component
#  x24: Sprott A chaotic oscillator, x-component
#  x25: Sprott A chaotic oscillator, y-component
#  x26: Sprott A chaotic oscillator, z-component
##
# -----------------------------------------------------------------------------
animation_loop: # Main loop for animation.

  c.jal clrscr

  li x2, memory

  # Bits inside of x2:
  # 0010 0000 0000 0000  0fff ffpp pppp p000
  # ----                                       RAM start address
  #                       --- --               Filament number
  #                             -- ---- -      Particle in filament
  #                                      ---   Size for x and y coordinates

# -----------------------------------------------------------------------------
oscillator:

   # J. C. Sprott, Some simple chaotic flows, 1994
   # "Sprott A" given as:

   # x-dot = y
   # y-dot = -x + yz
   # z-dot = 1 - y^2
   # (x0,y0,z0) = (0,5,0)

   # Differential equations integrated in fixpoint using Euler method:

   # int32_t xn = x + ((  y                                    ) >> EULER);
   # int32_t yn = y + (( -x              + ((y*z) >> FIXPOINT) ) >> EULER);
   # int32_t zn = z + (( (1 << FIXPOINT) - ((y*y) >> FIXPOINT) ) >> EULER);
   # x = xn; y = yn; z = zn;

   srai x13, x25, EULER

   mul x14, x25, x26
   srai x14, x14, FIXPOINT
   sub x14, x14, x24
   srai x14, x14, EULER

   mul x15, x25, x25
   srai x15, x15, FIXPOINT
   addi x15, x15, -1<<FIXPOINT
   srai x15, x15, EULER

   add x24, x24, x13
   add x25, x25, x14
   sub x26, x26, x15

# -----------------------------------------------------------------------------
particleloop:

  lw x10, 0(x2) # Particle x
  lw x11, 4(x2) # Particle y

  # Check if head or tail

  slli x15, x2,  32 - (LOGLENGTH+LOGDATASIZE)
  srai x15, x15, 32 -  LOGLENGTH
  addi x15, x15, 1
  c.bnez x15, tailparticle

# -----------------------------------------------------------------------------
headparticle:
    # Time for a new pseudorandom destination?
    slli x15, x12, 32-LOGDESTINATIONDURATION
    c.bnez x15, leadingfilament

newdestination:
      slli x22, x24, 32-4  # Derive new pseudorandom destination
      slli x23, x25, 32-4  # from the four least signficant bits
      srai x22, x22, 32-11 # of chaotic oscillator (x,y) components.
      srai x23, x23, 32-11 # Shift to a size of half the maximum range.

leadingfilament:
    mv x13, x22 # Get the prepared pseudorandom destion
    mv x14, x23

    srai x15, x25, 2  # Add in a little bit of current oscillator
    sub x13, x13, x15 # (y,x) components to the pseudorandom
    srai x15, x24, 2  # destination coordinates
    sub x14, x14, x15 # to keep the animation flowing

    # Check whether this is the leading filament:
    slli x15, x2,                            4 # Remove RAM start address
    srli x15, x15, LOGLENGTH + LOGDATASIZE + 4 # Remove particle-in-filament
    c.beqz x15, allfilaments

followingfilament:
      # When not the head of the first filament, follow the precedessor
      lw x13, -DATASIZE*LENGTH(x2)
      lw x14, -DATASIZE*LENGTH+4(x2)

allfilaments:
    li x7, -FOLLOW
    c.jal move

    mv x13, x25  # Expand the filaments using the chaotic oscillator (y,z)
    mv x14, x26
    li x7, EXPAND
    c.jal move

    j allparticles

# -----------------------------------------------------------------------------
tailparticle:

    lw x10, DATASIZE(x2)    # Just follow by copying the coordinates
    lw x11, DATASIZE+4(x2)  # of the next particle

# -----------------------------------------------------------------------------
allparticles:

  c.bnez x12, init_done
    li x10, 0  # Initialise particle coordinates on first loop run
    li x11, 0

init_done:

  sw x10, 0(x2) # Update coordinates in memory
  sw x11, 4(x2)

  addi x10, x10, 2047 # Shift coordinates to the middle
  addi x11, x11, 2047 #  of the DAC range
  c.jal paintpixel

  slli x10, x10, 16      # Prepare coordinates for DAC:
  slli x11, x11, 16      # Clip to 16 bit integer
  srli x11, x11, 16      # to avoid mixing sign into high part and combine
  or x10, x10, x11       # in the format of the two DAC channels output register.
# sw x10, DACC_R12DH(x3) # This way both channels get new values at the same moment

  addi x2, x2, DATASIZE  # Next particle

  slli x15, x2, 32 - (LOGFILAMENTS + LOGLENGTH + LOGDATASIZE)
  c.bnez x15, particleloop # Continue with next particle in this frame

  addi x12, x12, 1 # Increase frame counter
  j animation_loop

# -----------------------------------------------------------------------------
move: # Move (x10, x11) one step of size x7 towards destination (x13, x14)
# -----------------------------------------------------------------------------
  # x7  Step size
  # x10 Particle x
  # x11 Particle y
  # x13 Destination x
  # x14 Destination y

  # x8, x9, x15: Scratch

  sub x13, x13, x10  # dx
  sub x14, x14, x11  # dy

  srai x15, x13, 31  # abs(dx)
  add x8, x13, x15
  xor x8, x8, x15

  srai x15, x14, 31  # abs(dy)
  add x9, x14, x15
  xor x9, x9, x15

  add x9, x9, x8     # Use L1 norm for normalisation: abs(dx) + abs(dy)

  c.beqz x9, 1f      # Do not move when distance is zero.

    mul x13, x13, x7   # Select step size to move in that direction
    mul x14, x14, x7

    div x8, x13, x9    # Normalise distance vector
    div x9, x14, x9

    sub x10, x10, x8   # Move it!
    sub x11, x11, x9

1:ret

# -----------------------------------------------------------------------------
# signature: .byte 'M', 'e', 'c', 'r', 'i', 's', 'p', '.'
# -----------------------------------------------------------------------------

# Specials for framebuffer output:

# -----------------------------------------------------------------------------
paintpixel:
# -----------------------------------------------------------------------------
  li x15, 4095
  and x7, x10, x15
  and x8, x11, x15

  srli x7, x7, 2
  srli x8, x8, 2

  slli x7, x7, 2
  li x15, 1920*4
  mul x15, x15, x8
  add x7, x7, x15
  add x7, x7, x3

  li x15, 0x00FFFF
  sw x15, 0(x7)
  ret

# -----------------------------------------------------------------------------
clrscr:
# -----------------------------------------------------------------------------

  li x14, 4096    # Do not continue forever
  bge x12, x14, bye

  li x15, 7990000 # Wait a little
1:addi x15, x15, -1
  c.bnez x15, 1b

  mv x14, x3
  li x15, 1920*1080*4
  add x15, x15, x3

1:sw zero, 0(x14)
  addi x14, x14, 4
  bne x14, x15, 1b
  ret

# -----------------------------------------------------------------------------
bye:
# -----------------------------------------------------------------------------
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x17, 93                  # "exit"
    ecall                       # Final system call

device:  .ascii  "/dev/fb0\000"

# -----------------------------------------------------------------------------
.bss
# -----------------------------------------------------------------------------

.align 29, 0  # 0x20000000 # 32 kb RAM from 0x20000000 to 0x20008000

  .rept 0x2000
  .word 0x00000000
  .endr
