#ifndef _GPU_DIRECTX_H_
#define _GPU_DIRECTX_H_

#include <SDL.h>
#include <SDL_opengl.h>
#include <SDL_opengl_glext.h>
#include <d3d9.h>

SDL_Renderer* create_directx_renderer(SDL_Window*);
IDirect3DPixelShader9 **create_directx_shader(SDL_Renderer*);

#endif // _GPU_DIRECTX_H_
