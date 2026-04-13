#let project = "Project 4 Report"
#let author_1 = "Your Name"
#let student_id_1 = "12345678"

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


#placeholder[
  Describe the optimization work you completed.
  Mention the advanced replacement policies and prefetchers you implemented.
]

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

- which replacement policies and prefetchers you implemented
- whether you designed your own prefetcher

= Trace Analysis

- what access patterns you observed in your personalized trace
- how those patterns influenced your design decisions
- which student ID was used as the trace-generation seed

= Experimental Results

tables comparing configurations

= Best Configuration and Discussion

- your best-performing design
- why it performs well
- where it may still fail

= External Resources and AI Usage

List all external resources you relied on, including websites, textbooks, friends, and LLM tools.

#placeholder[
  You can keep this section in the following form and replace the bracketed fields:

  - Course materials:
    CSC3060 course handout and course slides on cache simulation and memory hierarchy.
  - Project specification:
    csc3060_spring2026_project4.pdf
  - External websites / references:
    [Write "None" if you did not use any.]
  - Discussion with classmates / friends:
    [Write "None" if not applicable.]
  - AI tools used:
    ChatGPT / Codex was used only as a writing and formatting assistant for preparing the report template and polishing wording. The implementation logic, experiment design, code, measurements, and final technical claims were reviewed and verified by the student before submission.
  - AI assistance scope:
    Helped summarize the required report sections from the project PDF and generate a Typst report template matching those requirements. [If you later use AI for code explanation, grammar correction, table formatting, or result phrasing, add that here.]
  - Link to the LLM conversation:
    [Paste the conversation link here if required by your instructor or by the platform you used.]
]
