# Fixed-point contract

## Coordinates and samples

Coordinates are unsigned Q4, 13 bits wide. Legal values are
`0 <= X_q4 <= 5120` and `0 <= Y_q4 <= 3840`. For a non-negative real
coordinate, host quantization is:

```text
coord_q4 = floor(real_coord * 16 + 0.5)
```

Out-of-range coordinates are host errors, not saturation. Pixel `(x,y)` uses
the centre sample `(x<<4)+8, (y<<4)+8`.

## Bounding box

For quantized vertices:

```text
min_x = min(v0.x,v1.x,v2.x)
max_x = max(v0.x,v1.x,v2.x)
min_y = min(v0.y,v1.y,v2.y)
max_y = max(v0.y,v1.y,v2.y)

xmin_raw = ceil((min_x - 8) / 16)
xmax_raw = floor((max_x - 8) / 16)
ymin_raw = ceil((min_y - 8) / 16)
ymax_raw = floor((max_y - 8) / 16)
```

The raw interval is intersected with x=0..319 and y=0..239. It is empty when
`xmin>xmax || ymin>ymax`; clamping must not turn an empty interval non-empty.
An AREA>0 triangle with an empty box is valid and produces zero candidates.
For the synthesizable setup result, D-029 maps this accepted empty result to
`TRI_SETUP_EMPTY` with canonical-zero bbox and initial-edge fields; the Python
reference continues to represent the mathematical empty bbox with `None`.

## Edge arithmetic

`dx` and `dy` are signed16; edge products, AREA, accumulators, and X/Y steps
are signed32. Coordinates are explicitly widened to signed before subtraction.
For `E=dx*(p.y-a.y)-dy*(p.x-a.x)`, a conservative legal bound is
`|E| <= 39,321,600`, within signed32. Increment bounds are
`|dy<<4| <= 61,440` and `|dx<<4| <= 81,920`.

Horizontal stepping adds `-(dy<<4)` and row stepping adds `(dx<<4)`.

## Attributes and quantization

Command starts and gradients are signed32 Q8. Host round-to-nearest uses ties
away from zero:

```text
scaled = real_value * 256
scaled >= 0: fixed = floor(scaled + 0.5)
scaled <  0: fixed = -floor(abs(scaled) + 0.5)
```

The result must fit signed32; there is no silent saturation. Internal row/current
accumulators are signed42 Q8. Sign-extend coefficients before arithmetic.
Signed42 is sufficient because the legal candidate extent gives
`|A| < (1+319+239)*2^31 < 2^41`; signed41 is not sufficient for unrestricted
signed32 command fields.

GFX-010 exposes raw covered R/G/B/Z values as signed42 Q8 fields. Signed32
command starts and gradients are sign-extended before every accumulator update;
there is no intermediate signed32 truncation, saturation, or quantization.
The raw mathematical value at `(x,y)` is the start at `(xmin,ymin)` plus the
signed42 X and Y gradient products. GFX-011 performs the later arithmetic
shift-right, clamp, colour packing, address, and depth operations.

Output conversion uses arithmetic shift right by 8 and then clamp; it does not
re-round. RGB clamps to 0..255. Z clamps to 0..254, where 255 is clear/
infinity.

## Colour, depth, and address

RGB332 is `{R8[7:5],G8[7:5],B8[7:6]}`. Z is unsigned8 with 0 nearest and
254 furthest drawable. A fragment writes both colour and Z only when
`new_z < old_z`; equal depth fails and writes neither. Address is unsigned17:
`addr=(y<<8)+(y<<6)+x`, range 0..76799.

RGB332 expansion is:

```text
R8 = {R3,R3,R3[2:1]}
G8 = {G3,G3,G3[2:1]}
B8 = {B2,B2,B2,B2}
```

Sobel edge output maps to RGB332 as `{edge[7:5],edge[7:5],edge[7:6]}`.
