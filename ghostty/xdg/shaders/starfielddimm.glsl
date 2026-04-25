// -----------------------------
// Starfield shader (dimmer + stable)
// -----------------------------

// transparent background
const bool transparent = false;

// terminal contents luminance threshold to be considered background (0.0 to 1.0)
const float threshold = 0.15;

// divisions of grid
const float repeats = 30.;

// number of layers
const float layers = 21.;

// ---- Fix parameters ----
const float starIntensity = 0.18;  // overall star brightness (0.10 .. 0.35)
const float sparkleClamp  = 2.2;   // clamps hotspot peaks (1.5 .. 4.0)
const float bgSoftness    = 0.08;  // softness around threshold (0.02 .. 0.12)
const float sparkleBias   = 0.02;  // prevents singularities (0.01 .. 0.06)
const float fadeStart     = 0.65;  // earlier depth fade (0.55 .. 0.85)

// star colors
const vec3 white = vec3(1.0); // pure white

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float N21(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

vec2 N22(vec2 p) {
    float n = N21(p);
    return vec2(n, N21(p + n));
}

mat2 scale(vec2 _scale) {
    return mat2(_scale.x, 0.0,
                0.0, _scale.y);
}

// 2D Noise based on Morgan McGuire
float noise(in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = N21(i);
    float b = N21(i + vec2(1.0, 0.0));
    float c = N21(i + vec2(0.0, 1.0));
    float d = N21(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

float perlin2(vec2 uv, int octaves, float pscale) {
    float col = 1.;
    float initScale = 4.;
    for (int l; l < octaves; l++) {
        float val = noise(uv * initScale);
        if (col <= 0.01) {
            col = 0.;
            break;
        }
        val -= 0.01;
        val *= 0.5;
        col *= val;
        initScale *= pscale;
    }
    return col;
}

vec3 stars(vec2 uv, float offset) {
    float timeScale = -(iTime + offset) / layers;
    float trans = fract(timeScale);
    float newRnd = floor(timeScale);
    vec3 col = vec3(0.);

    // Translate uv then scale for center
    uv -= vec2(0.5);
    uv = scale(vec2(trans)) * uv;
    uv += vec2(0.5);

    // Create square aspect ratio
    uv.x *= iResolution.x / iResolution.y;

    // Create boxes
    uv *= repeats;

    // Get position
    vec2 ipos = floor(uv);

    // Return uv as 0 to 1
    uv = fract(uv);

    // Calculate random xy and size
    vec2 rndXY = N22(newRnd + ipos * (offset + 1.)) * 0.9 + 0.05;
    float rndSize = N21(ipos) * 100. + 200.;

    vec2 j = (rndXY - uv) * rndSize;

    // ---- Fix 1: prevent singular hotspot + clamp peaks + global intensity
    float sparkle = 1.0 / (dot(j, j) + sparkleBias);
    sparkle = min(sparkle, sparkleClamp);
    col += white * sparkle * starIntensity;

    // ---- Fix 2: earlier, smoother depth fade (reduces overall “white wash”)
    float f = smoothstep(1.0, fadeStart, trans);
    // optional filmic fade curve (slightly darker)
    f = pow(f, 1.6);
    col *= f;

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    vec3 col = vec3(0.);

    for (float i = 0.; i < layers; i++) {
        col += stars(uv, i);
    }

    // Sample the terminal screen texture including alpha channel
    vec4 terminalColor = texture(iChannel0, uv);

    if (transparent) {
        col += terminalColor.rgb;
    }

    // ---- Fix 3: softer / smarter mask (stars mostly in dark background, but not harsh)
    float lum = luminance(terminalColor.rgb);

    // mask = 1 in dark background, 0 in brighter content, with softness band
    float mask = 1.0 - smoothstep(threshold - bgSoftness, threshold + bgSoftness, lum);

    // reduce stars in "not quite black" areas further (prevents glow over UI)
    mask *= (1.0 - lum * 0.6);

    vec3 blendedColor = mix(terminalColor.rgb, col, mask);

    // Apply terminal's alpha to control overall opacity
    fragColor = vec4(blendedColor, terminalColor.a);
}
