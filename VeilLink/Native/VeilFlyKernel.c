#include "VeilFlyKernel.h"

#include <string.h>

int32_t vlfly_validate_csr(
    uint32_t neuron_count,
    uint32_t edge_count,
    const uint32_t *offsets,
    const uint32_t *targets
) {
    if (neuron_count == 0 || offsets == NULL) return VFLY_KERNEL_INVALID_ARGUMENT;
    if (edge_count > 0 && targets == NULL) return VFLY_KERNEL_INVALID_ARGUMENT;
    if (offsets[0] != 0 || offsets[neuron_count] != edge_count) return VFLY_KERNEL_INVALID_GRAPH;

    uint32_t previous = 0;
    for (uint32_t neuron = 0; neuron <= neuron_count; ++neuron) {
        const uint32_t value = offsets[neuron];
        if (value < previous || value > edge_count) return VFLY_KERNEL_INVALID_GRAPH;
        previous = value;
    }
    for (uint32_t edge = 0; edge < edge_count; ++edge) {
        if (targets[edge] >= neuron_count) return VFLY_KERNEL_INVALID_GRAPH;
    }
    return VFLY_KERNEL_OK;
}

int32_t vlfly_validate_readout_csr(
    uint32_t neuron_count,
    uint32_t group_count,
    uint32_t membership_count,
    const uint32_t *neuron_group_offsets,
    const uint32_t *neuron_group_ids
) {
    if (neuron_count == 0 || group_count == 0 || neuron_group_offsets == NULL) {
        return VFLY_KERNEL_INVALID_ARGUMENT;
    }
    if (membership_count > 0 && neuron_group_ids == NULL) return VFLY_KERNEL_INVALID_ARGUMENT;
    if (neuron_group_offsets[0] != 0 || neuron_group_offsets[neuron_count] != membership_count) {
        return VFLY_KERNEL_INVALID_GRAPH;
    }

    uint32_t previous = 0;
    for (uint32_t neuron = 0; neuron <= neuron_count; ++neuron) {
        const uint32_t value = neuron_group_offsets[neuron];
        if (value < previous || value > membership_count) return VFLY_KERNEL_INVALID_GRAPH;
        previous = value;
    }
    for (uint32_t membership = 0; membership < membership_count; ++membership) {
        if (neuron_group_ids[membership] >= group_count) return VFLY_KERNEL_INVALID_GRAPH;
    }
    return VFLY_KERNEL_OK;
}

static int32_t vlfly_lif_step_hot_f32(
    uint32_t neuron_count,
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
    uint32_t *fired_out_count,
    const uint32_t *readout_offsets,
    const uint32_t *readout_groups,
    uint64_t *readout_totals
) {
    for (uint32_t spike = 0; spike < fired_in_count; ++spike) {
        const uint32_t source = fired_in[spike];
        const uint32_t begin = offsets[source];
        const uint32_t end = offsets[source + 1];
        for (uint32_t edge = begin; edge < end; ++edge) {
            current_scratch[targets[edge]] += weights[edge];
        }
    }

    uint32_t produced = 0;
    int32_t status = VFLY_KERNEL_OK;
    for (uint32_t neuron = 0; neuron < neuron_count; ++neuron) {
        const float synaptic = current_scratch[neuron];
        current_scratch[neuron] = 0.0f;  // fused clear: scratch is ready for the next tick
        float value = decay * voltage[neuron] + gain * synaptic + tonic;
        if (external_drive != NULL) value += external_drive[neuron];
        if (value >= threshold) {
            value = 0.0f;
            if (produced < fired_out_capacity) {
                fired_out[produced] = neuron;
            } else {
                status = VFLY_KERNEL_OUTPUT_OVERFLOW;
            }
            if (readout_totals != NULL) {
                const uint32_t begin = readout_offsets[neuron];
                const uint32_t end = readout_offsets[neuron + 1];
                for (uint32_t membership = begin; membership < end; ++membership) {
                    ++readout_totals[readout_groups[membership]];
                }
            }
            ++produced;
        }
        voltage[neuron] = value;
    }
    *fired_out_count = produced;
    return status;
}

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
) {
    if (neuron_count == 0 || offsets == NULL || voltage == NULL || current_scratch == NULL ||
        fired_out == NULL || fired_out_count == NULL) {
        return VFLY_KERNEL_INVALID_ARGUMENT;
    }
    if (edge_count > 0 && (targets == NULL || weights == NULL)) return VFLY_KERNEL_INVALID_ARGUMENT;
    if (fired_in_count > 0 && fired_in == NULL) return VFLY_KERNEL_INVALID_ARGUMENT;

    // The public single-step API preserves its defensive semantics: validate the externally
    // supplied spike indices and adjacency ranges before touching caller-owned state.
    for (uint32_t spike = 0; spike < fired_in_count; ++spike) {
        const uint32_t source = fired_in[spike];
        if (source >= neuron_count) return VFLY_KERNEL_INVALID_ARGUMENT;
        const uint32_t begin = offsets[source];
        const uint32_t end = offsets[source + 1];
        if (begin > end || end > edge_count) return VFLY_KERNEL_INVALID_GRAPH;
    }

    // Callers of the public step API are not required to provide zeroed scratch memory.
    memset(current_scratch, 0, (size_t)neuron_count * sizeof(float));
    return vlfly_lif_step_hot_f32(
        neuron_count, offsets, targets, weights,
        fired_in, fired_in_count, voltage, current_scratch, external_drive,
        decay, gain, tonic, threshold, fired_out, fired_out_capacity, fired_out_count,
        NULL, NULL, NULL
    );
}

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
) {
    if (neuron_count == 0 || offsets == NULL || voltage == NULL || current_scratch == NULL ||
        spike_a == NULL || spike_b == NULL || fired_inout_count == NULL || spike_capacity < neuron_count) {
        return VFLY_KERNEL_INVALID_ARGUMENT;
    }
    if (edge_count > 0 && (targets == NULL || weights == NULL)) return VFLY_KERNEL_INVALID_ARGUMENT;
    if (*fired_inout_count > spike_capacity) return VFLY_KERNEL_INVALID_ARGUMENT;

    // The graph is validated once by MaleCNSNativeGraph before entering this hot path. Validate
    // only the caller-provided initial spike list here; later lists are produced by this kernel.
    for (uint32_t i = 0; i < *fired_inout_count; ++i) {
        if (spike_a[i] >= neuron_count) return VFLY_KERNEL_INVALID_ARGUMENT;
    }

    uint32_t *input = spike_a;
    uint32_t *output = spike_b;
    uint32_t input_count = *fired_inout_count;
    uint64_t total = 0;

    // One clear per episode. vlfly_lif_step_hot_f32 then clears each slot while it already walks
    // the voltage array, eliminating one full-neuron memory pass from every subsequent tick.
    memset(current_scratch, 0, (size_t)neuron_count * sizeof(float));

    for (uint32_t step = 0; step < step_count; ++step) {
        uint32_t produced = 0;
        const int32_t status = vlfly_lif_step_hot_f32(
            neuron_count, offsets, targets, weights,
            input_count == 0 ? NULL : input, input_count,
            voltage, current_scratch, external_drive,
            decay, gain, tonic, threshold,
            output, spike_capacity, &produced,
            NULL, NULL, NULL
        );
        if (status != VFLY_KERNEL_OK) return status;

        total += produced;
        if (spike_counts != NULL) {
            for (uint32_t i = 0; i < produced; ++i) {
                ++spike_counts[output[i]];
            }
        }

        uint32_t *tmp = input;
        input = output;
        output = tmp;
        input_count = produced;
    }

    // Normalize the externally visible final-spike buffer to spike_a so Swift never has to care
    // whether the episode length was odd or even. The copy happens once per episode, not per step.
    if (input != spike_a && input_count > 0) {
        memmove(spike_a, input, (size_t)input_count * sizeof(uint32_t));
    }
    *fired_inout_count = input_count;
    if (total_spike_count != NULL) *total_spike_count = total;
    return VFLY_KERNEL_OK;
}


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
) {
    if (neuron_count == 0 || offsets == NULL || voltage == NULL || current_scratch == NULL ||
        spike_a == NULL || spike_b == NULL || fired_inout_count == NULL || spike_capacity < neuron_count ||
        group_count == 0 || neuron_group_offsets == NULL || group_totals == NULL) {
        return VFLY_KERNEL_INVALID_ARGUMENT;
    }
    if (edge_count > 0 && (targets == NULL || weights == NULL)) return VFLY_KERNEL_INVALID_ARGUMENT;
    if (membership_count > 0 && neuron_group_ids == NULL) return VFLY_KERNEL_INVALID_ARGUMENT;
    if (*fired_inout_count > spike_capacity) return VFLY_KERNEL_INVALID_ARGUMENT;
    if (neuron_group_offsets[0] != 0 || neuron_group_offsets[neuron_count] != membership_count) {
        return VFLY_KERNEL_INVALID_GRAPH;
    }

    for (uint32_t i = 0; i < *fired_inout_count; ++i) {
        if (spike_a[i] >= neuron_count) return VFLY_KERNEL_INVALID_ARGUMENT;
    }

    uint32_t *input = spike_a;
    uint32_t *output = spike_b;
    uint32_t input_count = *fired_inout_count;
    uint64_t total = 0;

    memset(current_scratch, 0, (size_t)neuron_count * sizeof(float));
    memset(group_totals, 0, (size_t)group_count * sizeof(uint64_t));

    for (uint32_t step = 0; step < step_count; ++step) {
        uint32_t produced = 0;
        const int32_t status = vlfly_lif_step_hot_f32(
            neuron_count, offsets, targets, weights,
            input_count == 0 ? NULL : input, input_count,
            voltage, current_scratch, external_drive,
            decay, gain, tonic, threshold,
            output, spike_capacity, &produced,
            neuron_group_offsets, neuron_group_ids, group_totals
        );
        if (status != VFLY_KERNEL_OK) return status;

        total += produced;

        uint32_t *tmp = input;
        input = output;
        output = tmp;
        input_count = produced;
    }

    if (input != spike_a && input_count > 0) {
        memmove(spike_a, input, (size_t)input_count * sizeof(uint32_t));
    }
    *fired_inout_count = input_count;
    if (total_spike_count != NULL) *total_spike_count = total;
    return VFLY_KERNEL_OK;
}

int32_t vlfly_reduce_readouts_u32(
    uint32_t neuron_count,
    const uint32_t *spike_counts,
    uint32_t group_count,
    const uint32_t *group_offsets,
    const uint32_t *group_neurons,
    uint32_t membership_count,
    uint64_t *group_totals
) {
    if (neuron_count == 0 || spike_counts == NULL || group_offsets == NULL || group_totals == NULL) {
        return VFLY_KERNEL_INVALID_ARGUMENT;
    }
    if (membership_count > 0 && group_neurons == NULL) return VFLY_KERNEL_INVALID_ARGUMENT;
    if (group_offsets[0] != 0 || group_offsets[group_count] != membership_count) {
        return VFLY_KERNEL_INVALID_GRAPH;
    }

    uint32_t previous = 0;
    for (uint32_t group = 0; group <= group_count; ++group) {
        const uint32_t offset = group_offsets[group];
        if (offset < previous || offset > membership_count) return VFLY_KERNEL_INVALID_GRAPH;
        previous = offset;
    }

    for (uint32_t group = 0; group < group_count; ++group) {
        uint64_t total = 0;
        const uint32_t begin = group_offsets[group];
        const uint32_t end = group_offsets[group + 1];
        for (uint32_t i = begin; i < end; ++i) {
            const uint32_t neuron = group_neurons[i];
            if (neuron >= neuron_count) return VFLY_KERNEL_INVALID_GRAPH;
            total += spike_counts[neuron];
        }
        group_totals[group] = total;
    }
    return VFLY_KERNEL_OK;
}
