module yeti16.display;

import std.file;
import std.path;
import std.stdio;
import std.string;
import core.stdc.stdlib;
import bindbc.sdl;
import yeti16.fonts; // TODO: remove
import yeti16.types;
import yeti16.computer;

class Display {
	Computer      computer;
	SDL_Window*   window;
	SDL_Renderer* renderer;
	SDL_Texture*  texture;
	uint[]        pixels;
	Vec2!int      resolution;

	this() {
		
	}

	void Init() {
		version (Windows) {
			auto res = loadSDL(format("%s/sdl2.dll", dirName(thisExePath())).toStringz());
		}
		else {
			auto res = loadSDL();
		}
	
		if (res != sdlSupport) {
			stderr.writeln("No SDL support");
			exit(1);
		}

		if (SDL_Init(SDL_INIT_VIDEO) < 0) {
			stderr.writefln("Failed to initialise SDL: %s", GetError());
			exit(1);
		}

		window = SDL_CreateWindow(toStringz("YETI-16"), 0, 0, 640, 400, 0);

		if (window is null) {
			stderr.writefln("Failed to create window: %s", GetError());
			exit(1);
		}

		renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

		if (renderer is null) {
			stderr.writefln("Failed to create renderer: %s", GetError());
			exit(1);
		}

		resolution = Vec2!int(320, 200);

		texture = SDL_CreateTexture(
			renderer, SDL_PIXELFORMAT_ABGR8888, SDL_TEXTUREACCESS_STREAMING,
			resolution.x, resolution.y
		);

		if (texture is null) {
			stderr.writefln("Failed to create texture: %s", GetError());
			exit(1);
		}

		pixels = new uint[](resolution.x * resolution.y);
	}

	string GetError() {
		return cast(string) SDL_GetError().fromStringz();
	}

	uint ColourToInt(ubyte r, ubyte g, ubyte b) {
		return r | (g << 8) | (b << 16) | (255 << 24);
	}

	void DrawPixel(uint x, uint y, ubyte r, ubyte g, ubyte b) {
		if ((x > resolution.x) || (y > resolution.y)) return;
		pixels[(y * resolution.x) + x] = ColourToInt(r, g, b);
	}

	void Render() {
		// TODO: multiple video modes
		// currently assumes 320x200 8bpp (mode 0x10)

		ubyte videoMode   = computer.ram[0x000404];
		auto  deathColour = SDL_Color(255, 0, 0, 255);
		bool  dead        = false;

		switch (videoMode) {
			case 0x00:
			case 0x01: {
				uint      textAddr;
				uint      attrAddr;
				uint      fontAddr;
				uint      paletteAddr;
				Vec2!uint cellDim;

				final switch (videoMode) {
					case 0x00: {
						textAddr    = 0x000405;
						attrAddr    = 0x0018B5;
						fontAddr    = 0x001085;
						paletteAddr = 0x001885;
						cellDim     = Vec2!uint(80, 40);
						break;
					}
					case 0x01: {
						textAddr    = 0x000405;
						attrAddr    = 0x001275;
						fontAddr    = 0x000A45;
						paletteAddr = 0x001245;
						cellDim     = Vec2!uint(40, 40);
						break;
					}
				}

				auto expectedRes = Vec2!int(
					cast(int) cellDim.x * 8, cast(int) cellDim.y * 8
				);
				if (resolution != expectedRes) {
					deathColour = SDL_Color(0, 0, 255, 255);
					goto default;
				}
			
				for (uint y = 0; y < cellDim.y; ++ y) {
					for (uint x = 0; x < cellDim.x; ++ x) {
						uint    chAddr = textAddr + (y * cellDim.x) + x;
						char    ch     = computer.ram[chAddr];
						ubyte[] chFont = computer.ram[
							fontAddr + (ch * 8) .. fontAddr + ((ch * 8) + 8)
						];
						ubyte attr  = computer.ram[attrAddr + (y * cellDim.x) + x];
						uint  fgCol = attr & 0x0F;
						uint  bgCol = (attr & 0xF0) >> 4;

						auto fg = SDL_Color(
							computer.ram[paletteAddr + (fgCol * 3)],
							computer.ram[paletteAddr + (fgCol * 3) + 1],
							computer.ram[paletteAddr + (fgCol * 3) + 2],
							255
						);
						auto bg = SDL_Color(
							computer.ram[paletteAddr + (bgCol * 3)],
							computer.ram[paletteAddr + (bgCol * 3) + 1],
							computer.ram[paletteAddr + (bgCol * 3) + 2]
						);

						for (uint cx = 0; cx < 8; ++ cx) {
							for (uint cy = 0; cy < 8; ++ cy) {
								auto pixelPos = Vec2!uint((x * 8) + cx, (y * 8) + cy);
							
								ubyte set = chFont[cy] & (1 << cx);

								if (set) {
									DrawPixel(pixelPos.x, pixelPos.y, fg.r, fg.g, fg.b);
								}
								else {
									DrawPixel(pixelPos.x, pixelPos.y, bg.r, bg.g, bg.b);
								}
							}
						}
					}
				}
				break;
			}
			case 0x10: {
				ubyte[256 * 3] paletteData = computer.ram[0x00FE05 .. 0x10105];

				for (uint i = 0x000405; i < 0x00FE05; ++ i) {
					uint  offset   = i - 0x000405;
					ubyte colour   = computer.ram[i];
					pixels[offset] = ColourToInt(
						paletteData[colour * 3],
						paletteData[(colour * 3) + 1],
						paletteData[(colour * 3) + 2]
					);
				}
				break;
			}
			default: {
				dead = true;
				SDL_SetRenderDrawColor(
					renderer, deathColour.r, deathColour.g, deathColour.b, 255
				);
				SDL_RenderClear(renderer);
				break;
			}
		}
		
		if (!dead) {
			SDL_UpdateTexture(texture, null, pixels.ptr, resolution.x * 4);
			SDL_RenderCopy(renderer, texture, null, null);
		}
		SDL_RenderPresent(renderer);
	}
}
