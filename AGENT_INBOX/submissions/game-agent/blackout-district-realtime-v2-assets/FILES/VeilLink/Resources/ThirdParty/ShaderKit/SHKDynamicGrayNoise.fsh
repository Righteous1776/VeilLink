//
// Creates moving grayscale noise.
//
// MIT License
//
// Copyright (c) 2017 Paul Hudson
// https://www.github.com/twostraws/ShaderKit
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

float random(float offset, vec2 tex_coord, float time) {
    vec2 non_repeating = vec2(12.9898 * time, 78.233 * time);
    float sum = dot(tex_coord, non_repeating);
    float sine = sin(sum);
    float huge_number = sine * 43758.5453 * offset;
    float fraction = fract(huge_number);
    return fraction;
}

void main() {
    vec4 current_color = SKDefaultShading();

    if (current_color.a > 0.0) {
        gl_FragColor = vec4(vec3(random(1.0, v_tex_coord, u_time)), 1) * current_color.a * v_color_mix.a;
    } else {
        gl_FragColor = current_color;
    }
}
