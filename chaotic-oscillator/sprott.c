
#include <stdio.h>
#include <stdint.h>

// ----------------------------------------------------------------------------
//   Chaotic oscillator
// ----------------------------------------------------------------------------

/*
  J. C. Sprott, Some simple chaotic flows, 1994
  "Sprott A" given as:

  x-dot = y
  y-dot = -x + yz
  z-dot = 1 - y^2
  (x0,y0,z0) = (0,5,0)

  Differential equations integrated in fixpoint using Euler method.

  How to use:

  clang -O3 -Wall -W -pedantic -fno-strict-aliasing sprott.c -o sprott && ./sprott > Chaos.txt
*/

#define FIXPOINT 10
#define EULER     5

int main()
{

  int32_t x = 0 << FIXPOINT;
  int32_t y = 5 << FIXPOINT;
  int32_t z = 0 << FIXPOINT;

  for (int p1 = 0; p1 < 100000; p1++) {

    printf("%i %i %i\n", x, y, z);

    int32_t xn = x + ((  y                                     ) >> EULER);
    int32_t yn = y + (( -x              + ((y*z) >> FIXPOINT)  ) >> EULER);
    int32_t zn = z + (( (1 << FIXPOINT) - ((y*y) >> FIXPOINT)  ) >> EULER);

    x = xn; y = yn; z = zn;
  }
  return(0);
}
