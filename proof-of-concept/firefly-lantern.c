// ----------------------------------------------------------------------------
//   Firefly Lantern, experiments for Lovebyte 2023 by Matthias Koch
// ----------------------------------------------------------------------------

/*
  clang -O3 -Wall -W -pedantic -fno-strict-aliasing firefly-lantern.c -o firefly-lantern -lm -lSDL && ./firefly-lantern
*/

#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <math.h>
#include <SDL/SDL.h>

// ----------------------------------------------------------------------------
//   Graphics primitives
// ----------------------------------------------------------------------------

void putpixel (SDL_Surface *canvas, int x, int y, Uint32 pixel)
{
  Uint32 *ptr = (Uint32 *) canvas->pixels;
  int lineoffset = y * (canvas->pitch) / 4;
  int pixelpos = lineoffset + x;
  ptr[pixelpos] = pixel;
}

Uint32 getpixel (SDL_Surface *canvas, int x, int y)
{
  Uint32 *ptr = (Uint32 *) canvas->pixels;
  int lineoffset = y * (canvas->pitch) / 4;
  int pixelpos = lineoffset + x;
  return ptr[pixelpos];
}

void clrscr  (SDL_Surface *canvas)
{
  Uint32 *ptr = (Uint32 *) canvas->pixels;
  memset(ptr, 0, canvas->w * canvas->h * 4);
}

// ----------------------------------------------------------------------------

void paintpixel(SDL_Surface *s, int x, int y, Uint32 pixel)
{
  x += 2047; y += 2047;
  x &= 4095; y &= 4095;
  x = x >> 3; y = y >> 3;

  for (uint32_t scalex = 0; scalex < 8; scalex++)
    for (uint32_t scaley = 0; scaley < 8; scaley++)
      putpixel(s, x+scalex, y+scaley, pixel);
}

void paintpixelfade(SDL_Surface *s, int x, int y, Uint32 pixel, Uint32 mask)
{
  x += 2047; y += 2047;
  x &= 4095; y &= 4095;
  x = x >> 3; y = y >> 3;

  for (uint32_t scalex = 0; scalex < 8; scalex++)
    for (uint32_t scaley = 0; scaley < 8; scaley++)
      putpixel(s, x+scalex, y+scaley, ((0x00004040 + getpixel(s, x+scalex, y+scaley)) & mask) | pixel);
}

// ----------------------------------------------------------------------------
//  Define selectable properties
// ----------------------------------------------------------------------------

#define LOGFILAMENTS 5
#define LOGLENGTH    7

#define LEAD    30
#define FOLLOW  30
#define EXPAND  16

#define FIXPOINT 10
#define EULER     5

#define OSCX 0 // -31
#define OSCY -16
#define OSCZ  -1

#define LOGDESTINATIONDURATION 6

// ----------------------------------------------------------------------------
//  Derived and fixed properties
// ----------------------------------------------------------------------------

#define FILAMENTS   (1<<LOGFILAMENTS)

#define LENGTH      (1<<LOGLENGTH)
#define LENGTHMASK ((1<<LOGLENGTH)-1)

struct coordinates {
    int32_t xPos;
    int32_t yPos;
} particles[FILAMENTS*LENGTH];

// ----------------------------------------------------------------------------
//   Move one step towards destination
// ----------------------------------------------------------------------------

void move(int32_t p, int32_t x, int32_t y, int32_t factor)
{
  int32_t dx = particles[p].xPos - x;
  int32_t dy = particles[p].yPos - y;

  if (abs(dx) + abs(dy) > 0)
  {
  particles[p].xPos -= factor * dx / (abs(dx) + abs(dy));
  particles[p].yPos -= factor * dy / (abs(dx) + abs(dy));
  }
}

// ----------------------------------------------------------------------------
//   Filament creature simulation
// ----------------------------------------------------------------------------

int main()
{
  // ----------------------------------------------------------

  for (uint32_t i = 0; i < FILAMENTS*LENGTH; i++)
  {
    particles[i].xPos = 0;
    particles[i].yPos = 0;
  }

  int32_t x = OSCX;
  int32_t y = OSCY;
  int32_t z = OSCZ;

  int32_t destinationx;
  int32_t destinationy;

  // ----------------------------------------------------------

  uint32_t frame = 0;

  SDL_Event e;
  SDL_Surface *s = SDL_SetVideoMode(512+8,512+8,32,0);

  do {

  // ----------------------------------------------------------

    int32_t xn = x + ((  y                                     ) >> EULER);
    int32_t yn = y + (( -x              + ((y*z) >> FIXPOINT)  ) >> EULER);
    int32_t zn = z + (( (1 << FIXPOINT) - ((y*y) >> FIXPOINT)  ) >> EULER);
    x = xn; y = yn; z = zn;

  // ----------------------------------------------------------

    if ((frame << (32-LOGDESTINATIONDURATION)) == 0)
    {
      destinationx = (x << (32-4)) >> (32-11);
      destinationy = (y << (32-4)) >> (32-11);
    }

    for (uint32_t particle = 0; particle < FILAMENTS*LENGTH; particle++)
    {
      if ((particle & LENGTHMASK) == LENGTHMASK)
      {
        if (particle>>LOGLENGTH) move(particle, particles[particle-LENGTH].xPos, particles[particle-LENGTH].yPos, FOLLOW);
        else                     move(particle, destinationx - (y >> 2),         destinationy - (x >> 2),         LEAD  );

        move(particle, y, z, -EXPAND);
      }
      else particles[particle] = particles[particle+1];
    }

  // ----------------------------------------------------------

    clrscr(s);

    for (uint32_t particle = 0; particle < FILAMENTS*LENGTH; particle++)
    {
      paintpixelfade(s, particles[particle].xPos, particles[particle].yPos,

        (particle>>LOGLENGTH) ?  (particle & LENGTHMASK) << (16-LOGLENGTH)          // Red
                              : ((particle & LENGTHMASK) << (16-LOGLENGTH)  ) << 8, // Blue-Green

        (particle>>LOGLENGTH) ? 0x00FF00FF : 0x00FFFF00
      );
    }

    // paintpixel(s, sy,           sz,           0x00FFFFFF);
    // paintpixel(s, destinationx, destinationy, 0x00FF00FF);

    printf("Frame: %i, Chaos: %i %i %i\n", frame, x, y, z);
    frame++;

    SDL_Flip(s);
    SDL_PollEvent(&e);
    usleep(12321);

  } while (!((e.type == SDL_QUIT) || e.type == SDL_KEYDOWN)); // End with keypress

  return(0);
}
