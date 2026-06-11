#!/usr/bin/env python3
"""
Dequantize Moonshine .onnx models from int8/uint8 quantized ops to FP32.

Replaces Microsoft contrib ops (DynamicQuantizeMatMul, MatMulIntegerToFloat,
FusedMatMul, QuickGelu, DequantizeLinear, DynamicQuantizeLinear) with standard
ONNX ops so the models work with OpenVINO EP. Weights are stored as float32;
the OpenVINO provider may still choose lower-precision kernels at runtime.

Usage:
    python3 dequantize-moonshine.py <input_dir> <output_dir>

Input:  directory with .onnx files (from .ort -> .onnx conversion)
Output: directory with FP32 .onnx files using only standard ONNX ops
"""

import sys
import os
import shutil
import numpy as np
import onnx
from onnx import helper, numpy_helper


def get_init(model, name):
    for init in model.graph.initializer:
        if init.name == name:
            return numpy_helper.to_array(init)
    return None


def find_producer(model, tensor_name):
    for node in model.graph.node:
        if tensor_name in node.output:
            return node
    return None


def dequant_array(quantized, scale, zp, axis=0):
    if scale.ndim == 0:
        return (quantized.astype(np.float32) - zp.astype(np.float32)) * scale.astype(
            np.float32
        )
    result = np.zeros_like(quantized, dtype=np.float32)
    slices_pre = [slice(None)] * axis
    for i in range(scale.shape[0]):
        idx = tuple(slices_pre + [i])
        zp_val = zp[i] if zp.ndim > 0 else zp
        result[idx] = (quantized[idx].astype(np.float32) - float(zp_val)) * float(
            scale[i]
        )
    return result


def find_quantized_source_init(model, tensor_name, visited=None):
    """Trace back through Gather/Slice/Unsqueeze to find the quantized initializer."""
    if visited is None:
        visited = set()
    if tensor_name in visited:
        return None
    visited.add(tensor_name)

    arr = get_init(model, tensor_name)
    if arr is not None and arr.dtype in (np.uint8, np.int8):
        return tensor_name

    producer = find_producer(model, tensor_name)
    if producer is None:
        return None

    for inp in producer.input:
        result = find_quantized_source_init(model, inp, visited)
        if result is not None:
            return result
    return None


WEIGHT_DTYPE = np.float32


def make_init(name, array):
    return numpy_helper.from_array(array.astype(WEIGHT_DTYPE), name)


def get_tensor_rank(model, tensor_name, _visited=None):
    """Get the rank of a tensor, tracing through rank-preserving ops if needed."""
    if _visited is None:
        _visited = set()
    if tensor_name in _visited:
        return None
    _visited.add(tensor_name)

    for vi in (
        list(model.graph.input)
        + list(model.graph.value_info)
        + list(model.graph.output)
    ):
        if vi.name == tensor_name and vi.type.HasField("tensor_type"):
            shape = vi.type.tensor_type.shape
            if shape is not None and len(shape.dim) > 0:
                return len(shape.dim)
    for init in model.graph.initializer:
        if init.name == tensor_name:
            return len(init.dims)

    producer = find_producer(model, tensor_name)
    if producer is None:
        return None

    RANK_PRESERVING = {
        "Concat",
        "Add",
        "Sub",
        "Mul",
        "Div",
        "Sigmoid",
        "Relu",
        "Tanh",
        "Softmax",
        "LayerNormalization",
        "Cast",
        "Pow",
        "Sqrt",
        "Neg",
        "Transpose",
        "Gather",
        "Where",
        "Clip",
        "Erf",
    }
    if producer.op_type in RANK_PRESERVING:
        return get_tensor_rank(model, producer.input[0], _visited)

    if producer.op_type == "Reshape":
        shape_init = get_init(model, producer.input[1])
        if shape_init is not None:
            return int(shape_init.shape[0])

    if producer.op_type == "Unsqueeze":
        base = get_tensor_rank(model, producer.input[0], _visited)
        if base is not None:
            axes_init = (
                get_init(model, producer.input[1]) if len(producer.input) > 1 else None
            )
            n_axes = (
                len(axes_init.flatten())
                if axes_init is not None
                else sum(1 for a in producer.attribute if a.name == "axes")
            )
            if n_axes == 0:
                for a in producer.attribute:
                    if a.name == "axes":
                        n_axes = len(a.ints)
            return base + n_axes

    if producer.op_type == "MatMul":
        r0 = get_tensor_rank(model, producer.input[0], _visited)
        r1 = get_tensor_rank(model, producer.input[1], _visited)
        if r0 is not None and r1 is not None:
            return max(r0, r1)

    return None


def last_two_transpose_perm(rank):
    """Return perm list that swaps only the last two dimensions."""
    return list(range(rank - 2)) + [rank - 1, rank - 2]


def dequantize_model(model):
    try:
        model = onnx.shape_inference.infer_shapes(model)
    except Exception:
        pass

    # Phase 1: Dequantize all quantized weight initializers in-place.
    # Find all DequantizeLinear nodes and their associated quantized initializers.
    # Dequantize the SOURCE initializer to FP32 and track the mapping.
    dequantized_inits = {}  # old_name -> new_fp32_name

    for node in list(model.graph.node):
        if node.op_type != "DequantizeLinear":
            continue

        scale_arr = get_init(model, node.input[1])
        zp_arr = (
            get_init(model, node.input[2])
            if len(node.input) > 2 and node.input[2]
            else np.array(0, dtype=np.uint8)
        )
        if scale_arr is None:
            continue

        axis = 0
        for attr in node.attribute:
            if attr.name == "axis":
                axis = attr.i

        # Find the quantized source initializer (may be through Gather/Slice/Unsqueeze)
        source_name = find_quantized_source_init(model, node.input[0])

        # Also check direct initializer
        if source_name is None:
            direct = get_init(model, node.input[0])
            if direct is not None and direct.dtype in (np.uint8, np.int8):
                source_name = node.input[0]

        if source_name is None:
            continue

        if source_name not in dequantized_inits:
            src_arr = get_init(model, source_name)
            fp32_arr = dequant_array(src_arr, scale_arr, zp_arr, axis)
            fp32_name = source_name.replace("_quantized", "_fp32").replace(
                "quantized", "fp32"
            )
            if fp32_name == source_name:
                fp32_name = source_name + "_fp32"

            model.graph.initializer.append(make_init(fp32_name, fp32_arr))
            dequantized_inits[source_name] = fp32_name

    # Phase 2: Rewire all references to quantized initializers to FP32 versions.
    for old_name, new_name in dequantized_inits.items():
        for node in model.graph.node:
            for j, inp in enumerate(node.input):
                if inp == old_name:
                    node.input[j] = new_name

    # Phase 3: Remove DequantizeLinear nodes — rewire consumers to use input[0].
    nodes_to_remove = []
    for node in list(model.graph.node):
        if node.op_type == "DequantizeLinear":
            dql_in = node.input[0]
            dql_out = node.output[0]
            for other in model.graph.node:
                if other is node:
                    continue
                for j, inp in enumerate(other.input):
                    if inp == dql_out:
                        other.input[j] = dql_in
            nodes_to_remove.append(node)

    # Phase 4: Replace other contrib ops.
    new_nodes = []

    for node in list(model.graph.node):
        if node in nodes_to_remove:
            continue

        if node.op_type == "DynamicQuantizeMatMul":
            a_input = node.input[0]
            b_name = node.input[1]
            has_bias = len(node.input) > 4 and node.input[4] != ""

            b_arr = get_init(model, b_name)
            b_scale = get_init(model, node.input[2])
            b_zp = get_init(model, node.input[3])

            if b_arr is not None and b_scale is not None and b_zp is not None:
                if b_arr.dtype in (np.uint8, np.int8):
                    b_fp32 = dequant_array(b_arr, b_scale, b_zp)
                else:
                    b_fp32 = b_arr.astype(np.float32)
                fp32_name = b_name + "_fp32"
                model.graph.initializer.append(make_init(fp32_name, b_fp32))

                if has_bias:
                    mm_out = node.output[0] + "_mm"
                    new_nodes.append(
                        helper.make_node("MatMul", [a_input, fp32_name], [mm_out])
                    )
                    new_nodes.append(
                        helper.make_node("Add", [mm_out, node.input[4]], node.output)
                    )
                else:
                    new_nodes.append(
                        helper.make_node("MatMul", [a_input, fp32_name], node.output)
                    )
                nodes_to_remove.append(node)

        elif node.op_type == "MatMulIntegerToFloat":
            a_quant = node.input[0]
            b_name = node.input[1]

            b_arr = get_init(model, b_name)
            b_scale = get_init(model, node.input[3])
            b_zp = (
                get_init(model, node.input[5])
                if len(node.input) > 5 and node.input[5]
                else np.array(0, dtype=np.uint8)
            )

            if b_arr is not None and b_scale is not None:
                if b_arr.dtype in (np.uint8, np.int8):
                    b_fp32 = dequant_array(b_arr, b_scale, b_zp)
                else:
                    b_fp32 = b_arr.astype(np.float32)
                fp32_name = b_name + "_fp32"
                model.graph.initializer.append(make_init(fp32_name, b_fp32))

                # Find FP32 input (before DynamicQuantizeLinear)
                a_fp32 = a_quant
                for other in model.graph.node:
                    if (
                        other.op_type == "DynamicQuantizeLinear"
                        and a_quant in other.output
                    ):
                        a_fp32 = other.input[0]
                        break

                new_nodes.append(
                    helper.make_node("MatMul", [a_fp32, fp32_name], node.output)
                )
                nodes_to_remove.append(node)

        elif node.op_type == "DynamicQuantizeLinear":
            nodes_to_remove.append(node)

        elif node.op_type == "FusedMatMul":
            alpha = 1.0
            transA = 0
            transB = 0
            for attr in node.attribute:
                if attr.name == "alpha":
                    alpha = attr.f
                elif attr.name == "transA":
                    transA = attr.i
                elif attr.name == "transB":
                    transB = attr.i

            a_in, b_in = node.input[0], node.input[1]
            cur = []

            if transA:
                out = a_in + "_T"
                rank = get_tensor_rank(model, a_in) or 4
                perm = last_two_transpose_perm(rank) if rank > 2 else None
                attrs = {"perm": perm} if perm else {}
                cur.append(helper.make_node("Transpose", [a_in], [out], **attrs))
                a_in = out
            if transB:
                out = b_in + "_T"
                rank = get_tensor_rank(model, b_in) or 4
                perm = last_two_transpose_perm(rank) if rank > 2 else None
                attrs = {"perm": perm} if perm else {}
                cur.append(helper.make_node("Transpose", [b_in], [out], **attrs))
                b_in = out

            if alpha != 1.0:
                mm_out = node.output[0] + "_mm"
                cur.append(helper.make_node("MatMul", [a_in, b_in], [mm_out]))
                alpha_name = node.output[0] + "_alpha"
                model.graph.initializer.append(
                    make_init(alpha_name, np.array(alpha, dtype=np.float32))
                )
                cur.append(helper.make_node("Mul", [mm_out, alpha_name], node.output))
            else:
                cur.append(helper.make_node("MatMul", [a_in, b_in], node.output))

            new_nodes.extend(cur)
            nodes_to_remove.append(node)

        elif node.op_type == "QuickGelu":
            alpha = 1.702
            for attr in node.attribute:
                if attr.name == "alpha":
                    alpha = attr.f

            x = node.input[0]
            alpha_name = node.output[0] + "_qg_a"
            model.graph.initializer.append(
                numpy_helper.from_array(np.array(alpha, dtype=np.float32), alpha_name)
            )

            s1 = node.output[0] + "_s1"
            s2 = node.output[0] + "_s2"
            new_nodes.append(helper.make_node("Mul", [x, alpha_name], [s1]))
            new_nodes.append(helper.make_node("Sigmoid", [s1], [s2]))
            new_nodes.append(helper.make_node("Mul", [x, s2], node.output))
            nodes_to_remove.append(node)

    # Apply changes
    for node in nodes_to_remove:
        if node in model.graph.node:
            model.graph.node.remove(node)
    model.graph.node.extend(new_nodes)

    # Remove unused initializers
    used = set()
    for node in model.graph.node:
        used.update(node.input)
    to_del = [i for i in model.graph.initializer if i.name not in used]
    for i in to_del:
        model.graph.initializer.remove(i)

    # Fix dangling graph outputs: some graph outputs (e.g. sample_buffer_out)
    # are pass-through from inputs but have no producing node. Add Identity nodes.
    node_outputs = set()
    for n in model.graph.node:
        node_outputs.update(n.output)
    init_names = {i.name for i in model.graph.initializer}
    input_names = {i.name for i in model.graph.input}
    for out in model.graph.output:
        if out.name in node_outputs or out.name in init_names:
            continue
        if out.name in input_names:
            # Output is same tensor as input (pure pass-through, no rename needed).
            # ONNX allows this — input IS the output. No Identity node needed.
            continue
        base = out.name
        if base.endswith("_out"):
            base = base[:-4]
        if base in input_names:
            model.graph.node.append(helper.make_node("Identity", [base], [out.name]))

    # Fix pass-through outputs (same name as graph input, no producing node).
    # ORT rejects these as "duplicate definitions". Add Identity nodes with
    # renamed outputs, then update the graph output entry to point to the new name.
    input_set = {i.name for i in model.graph.input}
    produced = set()
    for n in model.graph.node:
        produced.update(o for o in n.output if o)
    for out in model.graph.output:
        if out.name in input_set and out.name not in produced:
            new_name = out.name + "_id"
            model.graph.node.append(
                helper.make_node("Identity", [out.name], [new_name])
            )
            out.name = new_name

    # Clear stale value_info from shape inference (types may have changed)
    del model.graph.value_info[:]

    # Clean opset imports
    keep = [imp for imp in model.opset_import if imp.domain in ("", "ai.onnx.ml")]
    del model.opset_import[:]
    model.opset_import.extend(keep)
    if not any(imp.domain == "" for imp in model.opset_import):
        model.opset_import.append(helper.make_opsetid("", 18))

    return model


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input_dir> <output_dir>")
        sys.exit(1)

    input_dir, output_dir = sys.argv[1], sys.argv[2]
    os.makedirs(output_dir, exist_ok=True)

    for name in [
        "frontend",
        "encoder",
        "adapter",
        "cross_kv",
        "decoder_kv",
        "decoder_kv_with_attention",
    ]:
        src = os.path.join(input_dir, f"{name}.onnx")
        dst = os.path.join(output_dir, f"{name}.onnx")
        if not os.path.exists(src):
            continue

        print(f"\nDequantizing {name}.onnx ...")
        model = onnx.load(src)

        contrib = {
            "DynamicQuantizeMatMul",
            "MatMulIntegerToFloat",
            "FusedMatMul",
            "QuickGelu",
            "DequantizeLinear",
            "DynamicQuantizeLinear",
        }
        before = sum(1 for n in model.graph.node if n.op_type in contrib)
        print(f"  Before: {len(model.graph.node)} nodes, {before} contrib ops")

        model = dequantize_model(model)

        after = sum(1 for n in model.graph.node if n.op_type in contrib)
        print(f"  After:  {len(model.graph.node)} nodes, {after} contrib ops remaining")
        if after > 0:
            for n in model.graph.node:
                if n.op_type in contrib:
                    print(f"    remaining: {n.op_type} inputs={list(n.input)}")

        onnx.save(model, dst)
        print(
            f"  Size: {os.path.getsize(src) / 1024 / 1024:.1f} MB → {os.path.getsize(dst) / 1024 / 1024:.1f} MB"
        )

    for f in os.listdir(input_dir):
        if not f.endswith(".onnx"):
            src = os.path.join(input_dir, f)
            dst = os.path.join(output_dir, f)
            if os.path.isfile(src) and not os.path.exists(dst):
                shutil.copy2(src, dst)

    print("\nDone!")


if __name__ == "__main__":
    main()
