#include "A10UltraM5Native.h"
#include <math.h>
#include <string.h>

static float a10_sigmoid(float x) {
    return x >= 0.0f ? 1.0f / (1.0f + expf(-x)) : expf(x) / (1.0f + expf(x));
}

uint32_t a10_ultra_m5_native_abi_version(void) {
    return A10_ULTRA_M5_NATIVE_ABI_VERSION;
}

int a10_ultra_m5_reasoner_f32(
    const float *input,
    const float *input_weight,
    const float *hidden_bias,
    const float *output_weight,
    const float *output_bias,
    float *hidden,
    float *output
) {
    if (!input || !input_weight || !hidden_bias || !output_weight || !output_bias || !hidden || !output) return -1;

    for (size_t h = 0; h < A10_ULTRA_M5_REASONER_HIDDEN; ++h) {
        float a = hidden_bias[h];
        for (size_t i = 0; i < A10_ULTRA_M5_VOCAB_SIZE; ++i) {
            a += input[i] * input_weight[i * A10_ULTRA_M5_REASONER_HIDDEN + h];
        }
        hidden[h] = a > 0.0f ? a : 0.0f;
    }
    for (size_t o = 0; o < A10_ULTRA_M5_REASONER_OUTPUT; ++o) {
        float a = output_bias[o];
        for (size_t h = 0; h < A10_ULTRA_M5_REASONER_HIDDEN; ++h) {
            a += hidden[h] * output_weight[h * A10_ULTRA_M5_REASONER_OUTPUT + o];
        }
        output[o] = a10_sigmoid(a);
    }
    return 0;
}

int a10_ultra_m5_rnn_step_f32(
    const float *embedding,
    const float *recurrent,
    const float *hidden_bias,
    const float *output_weight,
    const float *output_bias,
    int32_t token_id,
    float *hidden_state,
    float *logits
) {
    if (!embedding || !recurrent || !hidden_bias || !output_weight || !output_bias || !hidden_state || !logits) return -1;
    if (token_id < 0 || token_id >= (int32_t)A10_ULTRA_M5_VOCAB_SIZE) return -2;

    float next[A10_ULTRA_M5_HIDDEN_SIZE];
    const float *e = embedding + ((size_t)token_id * A10_ULTRA_M5_HIDDEN_SIZE);
    for (size_t j = 0; j < A10_ULTRA_M5_HIDDEN_SIZE; ++j) {
        float a = e[j] + hidden_bias[j];
        for (size_t i = 0; i < A10_ULTRA_M5_HIDDEN_SIZE; ++i) {
            a += hidden_state[i] * recurrent[i * A10_ULTRA_M5_HIDDEN_SIZE + j];
        }
        next[j] = tanhf(a);
    }
    for (size_t o = 0; o < A10_ULTRA_M5_VOCAB_SIZE; ++o) {
        float a = output_bias[o];
        for (size_t j = 0; j < A10_ULTRA_M5_HIDDEN_SIZE; ++j) {
            a += next[j] * output_weight[j * A10_ULTRA_M5_VOCAB_SIZE + o];
        }
        logits[o] = a;
    }
    memcpy(hidden_state, next, sizeof(next));
    return 0;
}

int a10_ultra_m5_host_predictor_f32(
    const float input[A10_ULTRA_M5_HOST_FEATURES],
    const float *w1,
    const float *b1,
    const float *w2,
    const float *b2,
    const float *w3,
    const float *b3,
    float output[A10_ULTRA_M5_HOST_OUTPUT]
) {
    if (!input || !w1 || !b1 || !w2 || !b2 || !w3 || !b3 || !output) return -1;
    float h1[A10_ULTRA_M5_HOST_H1];
    float h2[A10_ULTRA_M5_HOST_H2];

    for (size_t r = 0; r < A10_ULTRA_M5_HOST_H1; ++r) {
        float a = b1[r];
        for (size_t c = 0; c < A10_ULTRA_M5_HOST_FEATURES; ++c) a += input[c] * w1[r * A10_ULTRA_M5_HOST_FEATURES + c];
        h1[r] = a > 0.0f ? a : 0.0f;
    }
    for (size_t r = 0; r < A10_ULTRA_M5_HOST_H2; ++r) {
        float a = b2[r];
        for (size_t c = 0; c < A10_ULTRA_M5_HOST_H1; ++c) a += h1[c] * w2[r * A10_ULTRA_M5_HOST_H1 + c];
        h2[r] = a > 0.0f ? a : 0.0f;
    }
    for (size_t r = 0; r < A10_ULTRA_M5_HOST_OUTPUT; ++r) {
        float a = b3[r];
        for (size_t c = 0; c < A10_ULTRA_M5_HOST_H2; ++c) a += h2[c] * w3[r * A10_ULTRA_M5_HOST_H2 + c];
        output[r] = a10_sigmoid(a);
    }
    return 0;
}


static int8_t a10_quantize_one(float value, float scale, int32_t zero_point) {
    long q = lrintf(value / scale) + (long)zero_point;
    if (q > 127) q = 127;
    if (q < -128) q = -128;
    return (int8_t)q;
}

static float a10_dynamic_symmetric_scale(const float *x, size_t n) {
    float max_abs = 0.0f;
    for (size_t i = 0; i < n; ++i) {
        float v = fabsf(x[i]);
        if (v > max_abs) max_abs = v;
    }
    return max_abs > 0.0f ? max_abs / 127.0f : 1.0f / 127.0f;
}

static int32_t a10_dot_i8(const int8_t *x, const int8_t *w, size_t n, int32_t xzp, int32_t wzp) {
    int32_t acc = 0;
    for (size_t i = 0; i < n; ++i) acc += ((int32_t)x[i] - xzp) * ((int32_t)w[i] - wzp);
    return acc;
}

int a10_ultra_m5_host_predictor_i8(
    const float input[A10_ULTRA_M5_HOST_FEATURES],
    const int8_t *w1, float w1_scale, int32_t w1_zero_point, const float *b1,
    const int8_t *w2, float w2_scale, int32_t w2_zero_point, const float *b2,
    const int8_t *w3, float w3_scale, int32_t w3_zero_point, const float *b3,
    float input_scale, int32_t input_zero_point,
    float output[A10_ULTRA_M5_HOST_OUTPUT]
) {
    if (!input || !w1 || !b1 || !w2 || !b2 || !w3 || !b3 || !output) return -1;
    if (!(input_scale > 0.0f) || !(w1_scale > 0.0f) || !(w2_scale > 0.0f) || !(w3_scale > 0.0f)) return -2;

    int8_t q0[32], q1[64], q2[32];
    float h1[64], h2[32];
    for (size_t i = 0; i < 32; ++i) q0[i] = a10_quantize_one(input[i], input_scale, input_zero_point);

    for (size_t r = 0; r < 64; ++r) {
        int32_t partial = a10_dot_i8(q0, w1 + r * 32, 32, input_zero_point, w1_zero_point);
        h1[r] = (float)partial * input_scale * w1_scale + b1[r];
        if (h1[r] < 0.0f) h1[r] = 0.0f;
    }
    float a1_scale = a10_dynamic_symmetric_scale(h1, 64);
    for (size_t i = 0; i < 64; ++i) q1[i] = a10_quantize_one(h1[i], a1_scale, 0);

    for (size_t r = 0; r < 32; ++r) {
        int32_t p0 = a10_dot_i8(q1, w2 + r * 64, 32, 0, w2_zero_point);
        int32_t p1 = a10_dot_i8(q1 + 32, w2 + r * 64 + 32, 32, 0, w2_zero_point);
        h2[r] = (float)(p0 + p1) * a1_scale * w2_scale + b2[r];
        if (h2[r] < 0.0f) h2[r] = 0.0f;
    }
    float a2_scale = a10_dynamic_symmetric_scale(h2, 32);
    for (size_t i = 0; i < 32; ++i) q2[i] = a10_quantize_one(h2[i], a2_scale, 0);

    for (size_t r = 0; r < 8; ++r) {
        int32_t acc = 0;
        for (size_t part = 0; part < 8; ++part) {
            size_t start = part * 4;
            acc += a10_dot_i8(q2 + start, w3 + r * 32 + start, 4, 0, w3_zero_point);
        }
        float z = (float)acc * a2_scale * w3_scale + b3[r];
        output[r] = a10_sigmoid(z);
    }
    return 0;
}
