#ifndef A10_ULTRA_M5_NATIVE_H
#define A10_ULTRA_M5_NATIVE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define A10_ULTRA_M5_NATIVE_ABI_VERSION 1u
#define A10_ULTRA_M5_VOCAB_SIZE 69u
#define A10_ULTRA_M5_HIDDEN_SIZE 96u
#define A10_ULTRA_M5_REASONER_HIDDEN 64u
#define A10_ULTRA_M5_REASONER_OUTPUT 11u
#define A10_ULTRA_M5_HOST_FEATURES 32u
#define A10_ULTRA_M5_HOST_H1 64u
#define A10_ULTRA_M5_HOST_H2 32u
#define A10_ULTRA_M5_HOST_OUTPUT 8u

uint32_t a10_ultra_m5_native_abi_version(void);

int a10_ultra_m5_reasoner_f32(
    const float *input,
    const float *input_weight,
    const float *hidden_bias,
    const float *output_weight,
    const float *output_bias,
    float *hidden,
    float *output
);

int a10_ultra_m5_rnn_step_f32(
    const float *embedding,
    const float *recurrent,
    const float *hidden_bias,
    const float *output_weight,
    const float *output_bias,
    int32_t token_id,
    float *hidden_state,
    float *logits
);

int a10_ultra_m5_host_predictor_f32(
    const float input[A10_ULTRA_M5_HOST_FEATURES],
    const float *w1,
    const float *b1,
    const float *w2,
    const float *b2,
    const float *w3,
    const float *b3,
    float output[A10_ULTRA_M5_HOST_OUTPUT]
);

int a10_ultra_m5_host_predictor_i8(
    const float input[A10_ULTRA_M5_HOST_FEATURES],
    const int8_t *w1, float w1_scale, int32_t w1_zero_point, const float *b1,
    const int8_t *w2, float w2_scale, int32_t w2_zero_point, const float *b2,
    const int8_t *w3, float w3_scale, int32_t w3_zero_point, const float *b3,
    float input_scale, int32_t input_zero_point,
    float output[A10_ULTRA_M5_HOST_OUTPUT]
);

#ifdef __cplusplus
}
#endif

#endif
