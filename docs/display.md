# Display
Current video mode is stored in `0x000404`

Note: After changing the current video mode, you need to update the display by sending
the ASCII character `M` to the YETI-16 Graphics Controller

## Video modes

### 0x00
80x40 text mode with 8x8 font

Text data is stored in 0x000405 - 0x001085

Font data is stored in 0x001085 - 0x001885

Palette data is stored in 0x001885 - 0x0018B5

Attribute data is stored in 0x0018B5 - 0x002535

### 0x01
40x40 text mode with 8x8 font

Text data is stored in 0x000405 - 0x000A45

Font data is stored in 0x000A45 - 0x001245

Palette data is stored in 0x001245 - 0x001275

Attribute data is stored in 0x001275 - 0x0018B5

### 0x10
320x200 video mode with 8bpp

Pixel data is stored in 0x000405 - 0x00FE05

Palette data is stored in 0x00FE05 - 0x10105

## Text data
Text data is stored in 2 buffers:
- Characters
- Attributes

Attributes are formatted like this (as a byte):
```
B B B B F F F F
```
B = background colour

F = foreground colour
