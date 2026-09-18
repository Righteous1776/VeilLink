#ifndef VEIL_FLY_KERNEL_H
#define VEIL_FLY_KERNEL_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
    VFLY_KERNEL_OK = 0,
    VFLY_KERNEL_INVALID_ARGUMENT = 1,
    VFLY_KERNEL_INVALID_GRAPH = 2,
    VFLY_KERNEL_OUTPUT_OVERFLOW = 3
};

/// Validate one outgoing-adjacency CSR graph once at load time.
/// offsets must contain neuron_count + 1 entries and end at edge_count.
int32_t vlfly_validate_csr(
    uint32_t neuron_count,
    uint32_t edge_count,
    const uint32_t *offsets,
    const uint32_t *targets
);

/// Validate an inverted readout-membership CSR once at map construction time.
/// neuron_group_offsets has neuron_count + 1 entries; neuron_group_ids stores group indexes.
int32_t vlfly_validate_readout_csr(
    uint32_t neuron_count,
    uint32_t group_count,
    uint32_t membership_count,
    const uint32_t *neuron_group_offsets,
    const uint32_t *neuron_group_ids
);

/// Fused deterministic LIF step over a graph that has already passed vlfly_validate_csr.
///
/// No heap allocation is performed. current_scratch must contain neuron_count floats and is
/// zeroed/reused by this function. external_drive may be NULL; when present it must contain
/// neuron_count floats. fired_out capacity should normally equal neuron_count.
int32_t vlfly_lif_step_f32(
    uint32_t neuron_count,
    uint32_t edge_count,
    const uint32_t *offsets,
    const uint32_t *targets,
    const float *weights,
    const uint32_t *fired_in,
    uint32_t fired_in_count,
    float *voltage,
    float *current_scratch,
    const float *external_drive,
    float decay,
    float gain,
    float tonic,
    float threshold,
    uint32_t *fired_out,
    uint32_t fired_out_capacity,
    uint32_t *fired_out_count
);

/// Run multiple deterministic LIF steps inside one native call. This is the preferred episode
/// hot path because it amortizes the Swift/C boundary. spike_a must contain the initial fired
/// indices in its first *fired_inout_count entries; spike_b is an equally-sized scratch/output
/// buffer. On success, the final step's fired indices are copied back into spike_a and
/// *fired_inout_count is updated. spike_counts may be NULL; when present it must contain
/// neuron_count uint32 values and is incremented for every spike produced during the episode.
int32_t vlfly_lif_run_f32(
    uint32_t neuron_count,
    uint32_t edge_count,
    const uint32_t *offsets,
    const uint32_t *targets,
    const float *weights,
    uint32_t *spike_a,
    uint32_t *spike_b,
    uint32_t spike_capacity,
    uint32_t *fired_inout_count,
    float *voltage,
    float *current_scratch,
    const float *external_drive,
    float decay,
    float gain,
    float tonic,
    float threshold,
    uint32_t step_count,
    uint32_t *spike_counts,
    uint64_t *total_spike_count
);

/// Run a deterministic episode while accumulating only compact readout-group totals.
/// The readout map must have passed vlfly_validate_readout_csr. This path avoids writing a
/// neuron_count-sized spike-count array when higher layers only need selected readouts.
int32_t vlfly_lif_run_readouts_f32(
    uint32_t neuron_count,
    uint32_t edge_count,
    const uint32_t *offsets,
    const uint32_t *targets,
    const float *weights,
    uint32_t *spike_a,
    uint32_t *spike_b,
    uint32_t spike_capacity,
    uint32_t *fired_inout_count,
    float *voltage,
    float *current_scratch,
    const float *external_drive,
    float decay,
    float gain,
    float tonic,
    float threshold,
    uint32_t step_count,
    uint32_t group_count,
    const uint32_t *neuron_group_offsets,
    const uint32_t *neuron_group_ids,
    uint32_t membership_count,
    uint64_t *group_totals,
    uint64_t *total_spike_count
);

/// Reduce per-neuron spike counts into compact, possibly overlapping readout groups.
/// group_offsets has group_count + 1 entries and indexes group_neurons. Each group total is
/// overwritten on success. No heap allocation is performed.
int32_t vlfly_reduce_readouts_u32(
    uint32_t neuron_count,
    const uint32_t *spike_counts,
    uint32_t group_count,
    const uint32_t *group_offsets,
    const uint32_t *group_neurons,
    uint32_t membership_count,
    uint64_t *group_totals
);

#ifdef __cplusplus
}
#endif

#endif
