#let project = "Project 4 Report"
#let author_1 = "Haoyu Ren"
#let student_id_1 = "124090521"

#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 0.9in),
  numbering: "1",
)

#set text(
  font: "Libertinus Serif",
  size: 11pt,
)

#set par(justify: true, leading: 0.7em)
#set heading(numbering: "1.")

#let placeholder(body) = block(
  inset: 10pt,
  radius: 6pt,
  fill: luma(245),
  stroke: 0.6pt + luma(215),
  below: 0.8em,
)[#body]

#let terminal-block(body) = block(
  inset: 10pt,
  radius: 6pt,
  fill: luma(245),
  stroke: 0.6pt + luma(215),
  below: 0.8em,
)[
  #raw(body, block: true)
]

#let result-table(
  enable_l2: true,
  l1_hit_rate: "21.43%",
  l1_access: "56",
  l1_miss: "44",
  l1_wb: "2",
  l1_prefetches: "0",
  l2_hit_rate: "50.00%",
  l2_access: "46",
  l2_miss: "23",
  l2_wb: "0",
  l2_prefetches: "0",
  memory_accesses: "23",
  total_instructions: "56",
  total_cycles: "2532",
  amat: "45.21 cycles",
) = {
  let l1_line = (
    "[L1] Hit Rate: " + str(l1_hit_rate)
    + " (Access: " + str(l1_access)
    + ", Miss: " + str(l1_miss)
    + ", WB: " + str(l1_wb) + ")\n"
    + "    Prefetches Issued: " + str(l1_prefetches)
  )

  let l2_line = if enable_l2 {
    (
      "\n[L2] Hit Rate: " + str(l2_hit_rate)
      + " (Access: " + str(l2_access)
      + ", Miss: " + str(l2_miss)
      + ", WB: " + str(l2_wb) + ")\n"
      + "    Prefetches Issued: " + str(l2_prefetches)
    )
  } else {
    ""
  }

  let memory_line = ("\n[Main Memory] Total Accesses: " + str(memory_accesses))

  let metrics = (
    "\n\nMetrics:\n"
    + "Total Instructions: " + str(total_instructions) + "\n"
    + "Total Cycles:       " + str(total_cycles) + "\n"
    + "AMAT:               " + str(amat)
  )

  terminal-block(
    l1_line + l2_line + memory_line + metrics
  )
}

#align(center)[
  #text(size: 22pt, weight: "bold")[#project]
]

= Info

#v(1.0em)

#table(
  columns: (1fr, 2fr),
  stroke: 0.5pt + luma(200),
  inset: 7pt,
  [Name],
  [#author_1],
  [Student ID (seed)],
  [#student_id_1]
)

= Implementation Summary

== Task 1

Implemented: 

#v(-0.5em)

#placeholder[
  ```cpp 
  CacheLevel::get_index();
  CacheLevel::get_tag();
  CacheLevel::reconstruct_addr();
  CacheLevel::write_back_victim();
  CacheLevel::access();
  Class LRUPolicy;
  ```
]

== Task 2

Add to create L2 cache and connect it to memory:

#v(-0.5em)

#placeholder[
    ```cpp
    l2 = new CacheLevel("L2", l2_cfg, memory);
    ```
]

Replace the error printing by:

#v(-0.5em)

#placeholder[
    ```cpp
    if (enable_l2) {
        l1_next = l2;
    }
    ```
]

which also routes L1 misses to L2 instead of main memory.

== Task 3

Implemented cache optimizations by adding configurable replacement and prefetch components so the simulator can evaluate policies beyond the baseline hierarchy.
The implementation includes the advanced replacement policies `SRRIP` and `BIP`, together with the `NextLine` and `Stride` prefetchers.

= Address Mapping Explanation

#table(
  columns: (2.6fr, 2.2fr, 2fr),
  stroke: 0.5pt + luma(200),
  inset: 6pt,
  [`[64: offset_bits + index_bits + 1]`],
  [`[offset_bits + index_bits: offset_bits + 1]`],
  [`[offset_bits : 1]`],
  [tag],
  [Index],
  [offset],
)

```cpp get_index()``` first shifts away the block offset, then uses a mask to keep only the set-index bits. ```cpp get_tag()``` shifts away both the block offset and the set index, so the remaining upper bits are the tag.

When cache geometry changes, the field boundaries change with it: larger blocks use more offset bits, and more sets use more index bits.

= Task 1 Testing

Task 1 was tested under multiple cache geometries by changing the cache size, associativity, and block size. The test set covered direct-mapped caches (`assoc = 1`), set-associative caches, and a fully associative case by setting associativity equal to the number of lines in the cache.

Representative results:

#table(
  columns: (2.4fr, 1.2fr, 1fr, 1.1fr, 1.1fr),
  stroke: 0.5pt + luma(200),
  inset: 6pt,
  [Configuration],
  [Hit Rate],
  [Miss],
  [Cycles],
  [AMAT],

  [Fully associative, 1KB, B64],
  [58.93%],
  [23],
  [2356],
  [42.07],

  [2-way set-assoc, 1KB, B64],
  [21.43%],
  [44],
  [4456],
  [79.57],

  [Direct-mapped, 1KB, B64],
  [21.43%],
  [44],
  [4456],
  [79.57],

  [4-way set-assoc, 2KB, B64],
  [21.43%],
  [44],
  [4456],
  [79.57],

  [4-way set-assoc, 1KB, B16],
  [21.43%],
  [44],
  [4456],
  [79.57],
)

= Task 2 Hierarchy Explanation

The hierarchy is connected as a chain of next-level pointers. L1 handles every trace access first. On an L1 hit, the request is completed at L1 latency. On an L1 miss, `access()` forwards the same block request to its next level. After Task 2, that next level is L2 when L2 is enabled; otherwise it is main memory. L2 follows the same rule: an L2 hit serves the block at L2 latency, while an L2 miss forwards the request again to main memory.

Dirty evictions also move down the hierarchy. When L1 or L2 replaces a dirty line, `write_back_victim()` reconstructs the block address and sends a write to the next level, so modified data is propagated downward instead of being dropped.

The following results shows that after enabling L2 cache, 27 main-memory accesses are avoided.

#result-table(
  l1_hit_rate: "21.43%",
  l1_access: "56",
  l1_miss: "44",
  l1_wb: "6",
  l1_prefetches: "0",
  l2_hit_rate: "54.00%",
  l2_access: "50",
  l2_miss: "23",
  l2_wb: "0",
  l2_prefetches: "0",
  memory_accesses: "23",
  total_instructions: "56",
  total_cycles: "2532",
  amat: "45.21 cycles",
)

= Task 3 Design Choices

- Implemented replacement policies: `LRU`, `SRRIP`, and `BIP`.

- Implemented prefetchers: `NextLine` and `Stride`.

- No extra prefetcher are implemented.

= Trace Analysis

#placeholder()[The trace-generation seed was `124090521`.]

Using `python3 trace_analyzer.py my_trace.txt --block-size 64 --assoc 16 --top 50 --window-size 64`, the dominant strides are:

- `+7`: `4052` accesses (`45.19%`)
- `+1`: `2263` accesses (`25.24%`)
- `+64`: `1563` accesses (`17.43%`)

The stride profile already suggests regular access behavior, and the `+64` component is especially important because the 14 most frequently accessed blocks also happen to form a stride-`64` sequence. The per-window summary provides a second clue: in trace [2560, 4416), every 64-access window touches only one set and exactly 14 distinct blocks. The matching count and stride suggested that 14 blocks mapped to the same set were being heavily interleaved in a short period.

Based on this clue, I chose `assoc = 16` as a heuristic design decision. With 16 ways, one set can hold all 14 competing blocks at the same time, which should eliminate the conflict misses caused by repeatedly evicting them. The experimental results were consistent with this hypothesis and gave good performance.

= Experimental Results

All Task 3 runs below use a `32KB` L1, `64B` blocks, `1`-cycle L1 latency, and `100`-cycle main-memory latency. When L2 is enabled, the simulator creates a `128KB`, `4`-cycle L2 automatically.

Hierarchy baseline and prefetch comparison (`assoc = 16`):

#table(
  columns: (1.2fr, 1.2fr, 0.95fr, 0.95fr, 1.1fr, 0.8fr),
  stroke: 0.5pt + luma(200),
  inset: 6pt,
  [L1],
  [L2],
  [L1 Hit Rate],
  [L2 Hit Rate],
  [Memory Accesses],
  [AMAT],

  [LRU + None],
  [LRU + None],
  [30.27%],
  [72.99%],
  [1746],
  [23.25],

  [LRU + NextLine],
  [LRU + None],
  [90.87%],
  [75.39%],
  [1795],
  [3.54],

  [LRU + Stride],
  [LRU + None],
  [94.52%],
  [73.16%],
  [1758],
  [2.65],

  [LRU + Stride],
  [LRU + Stride],
  [94.52%],
  [96.88%],
  [1770],
  [1.98],

  [LRU + Stride],
  [LRU + NextLine],
  [94.52%],
  [96.97%],
  [1809],
  [1.63],
)

Replacement-policy and mixed-level comparison (`assoc = 16`):

#table(
  columns: (1.2fr, 1.2fr, 0.95fr, 0.95fr, 1.1fr, 0.8fr),
  stroke: 0.5pt + luma(200),
  inset: 6pt,
  [L1],
  [L2],
  [L1 Hit Rate],
  [L2 Hit Rate],
  [Memory Accesses],
  [AMAT],

  [LRU + Stride],
  [LRU + NextLine],
  [94.52%],
  [96.97%],
  [1809],
  [1.63],

  [SRRIP + Stride],
  [LRU + NextLine],
  [94.38%],
  [96.92%],
  [1810],
  [1.64],

  [BIP + Stride],
  [LRU + NextLine],
  [89.26%],
  [96.68%],
  [1809],
  [1.84],

  [LRU + Stride],
  [SRRIP + NextLine],
  [94.52%],
  [96.96%],
  [1811],
  [1.63],

  [LRU + Stride],
  [BIP + NextLine],
  [94.52%],
  [94.35%],
  [2178],
  [1.74],
)

Associativity sensitivity for the best hierarchy (`L1 = LRU + Stride`, `L2 = LRU + NextLine`):

#table(
  columns: (0.8fr, 1fr, 1fr, 1.2fr, 0.8fr),
  stroke: 0.5pt + luma(200),
  inset: 6pt,
  [Assoc],
  [L1 Hit Rate],
  [L2 Hit Rate],
  [Memory Accesses],
  [AMAT],

  [4],
  [83.03%],
  [97.49%],
  [1811],
  [2.09],

  [8],
  [83.26%],
  [97.52%],
  [1811],
  [2.08],

  [16],
  [94.52%],
  [96.97%],
  [1809],
  [1.63],

  [32],
  [95.41%],
  [96.87%],
  [1809],
  [1.60],
)

= Best Configuration and Discussion

The best measured configuration was a `32KB` `32`-way L1 using `LRU + Stride` and an enabled `128KB` `32`-way L2 using `LRU + NextLine`. This hierarchy achieved `AMAT = 1.60`, improving substantially over the two-level baseline `LRU + None / LRU + None` at `AMAT = 23.25`, and it also beat the provided `Best_AMAT = 1.78`.

This design fits the trace characteristics well. The trace is dominated by regular `+7`, `+1`, and `+64` block strides, so `Stride` is the most effective L1 prefetcher and removes most of the front-end miss cost. After that filtering, the residual stream seen by L2 is more local and near-sequential, which is why `NextLine` at L2 slightly outperformed `Stride` there. The replacement-policy comparison also showed that `BIP` was weaker on this trace, which is consistent with a workload that reuses lines quickly instead of favoring very conservative insertion. The design may still perform worse on traces with irregular or rapidly changing access patterns, because both prefetchers depend on short-term regularity and `NextLine` can waste capacity by fetching adjacent blocks that are never used.

= External Resources and AI Usage

#placeholder[

  *Course materials*
  - CSAPP
  - https://zhuanlan.zhihu.com/p/591436083
  - https://blog.csdn.net/weixin_52310423/article/details/139928135
  - https://blog.csdn.net/m0_73482688/article/details/127720841

  *AI tools*
  
  Codex was used for:
  - Preparing the typst template for report (see `codex session 1.md`)
    
  - Discussing the performance bias of `Stripe` and `NextLine` prefetchers on L2 (see `codex session 2.md`)

  - Finding the pattern of hot blocks (see `codex session 3.md`) 

]
