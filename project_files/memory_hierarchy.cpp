#include "memory_hierarchy.h"
#include "prefetcher.h"
#include "repl_policy.h"
#include <cmath>
#include <iomanip>
#include <iostream>

using namespace std;

MainMemory::MainMemory(int lat) : latency(lat) {}

int MainMemory::access(uint64_t addr, char type, uint64_t cycle) {
    (void)addr;
    (void)type;
    (void)cycle;
    access_count++;
    return latency;
}

void MainMemory::printStats() {
    cout << "  [Main Memory] Total Accesses: " << access_count << endl;
}

CacheLevel::CacheLevel(string name, CacheConfig cfg, MemoryObject* next)
    : level_name(name), config(cfg), next_level(next) {
    policy = createReplacementPolicy(config.policy_name);
    prefetcher = createPrefetcher(config.prefetcher, config.block_size);

    uint64_t total_bytes = (uint64_t)config.size_kb * 1024;
    num_sets = total_bytes / (config.block_size * config.associativity);

    offset_bits = log2(config.block_size);
    index_bits = log2(num_sets);

    sets.resize(num_sets, vector<CacheLine>(config.associativity));

    cout << "Constructed " << level_name << ": "
         << config.size_kb << "KB, " << config.associativity << "-way, "
         << config.latency << "cyc, "
         << "[" << config.policy_name << " + " << prefetcher->getName() << "]" << endl;
}

CacheLevel::~CacheLevel() {
    delete policy;
    delete prefetcher;
}

uint64_t CacheLevel::get_index(uint64_t addr) {
    return (addr >> offset_bits) & ~((int64_t)-1 << index_bits);
}

uint64_t CacheLevel::get_tag(uint64_t addr) {
    return addr >> offset_bits + index_bits;
}

uint64_t CacheLevel::reconstruct_addr(uint64_t tag, uint64_t index) {
    return (tag << offset_bits + index_bits) | (index << offset_bits);
}

void CacheLevel::write_back_victim(const CacheLine& line, uint64_t index, uint64_t cycle) {
    if (!line.dirty) {
        return;
    }
    ++write_backs;
    uint64_t evicted_addr = reconstruct_addr(line.tag, index);
    next_level->access(evicted_addr, 'w', cycle);

}

int CacheLevel::access(uint64_t addr, char type, uint64_t cycle) {
    // TODO: Task 1
    // 1. Derive the address fields for the current cache geometry:
    //    - block offset bits
    //    - set index bits
    //    - tag bits
    // 2. Use the address to compute index/tag and select the set.
    // 3. Search all ways for a valid tag match.
    // 4. On hit:
    //    - increment hits
    //    - call policy->onHit(...)
    //    - update dirty bit for writes
    //    - clear is_prefetched if a prefetched line is consumed
    // 5. On miss:
    //    - increment misses
    //    - find an invalid line or select a victim with policy->getVictim(...)
    //    - call write_back_victim(...) if the chosen victim is dirty
    //    - fetch the requested block from next_level and add that latency to lat
    //    - install the new cache line and call policy->onMiss(...)
    // 6. Your code should work correctly even if cache size, associativity,
    //    number of sets, or cache line size changes.
    // 7. Task 3: after demand access logic works, call the prefetcher here and
    //    install returned blocks through install_prefetch(...).

    uint64_t index = get_index(addr);
    uint64_t tag = get_tag(addr);
    bool miss = true;
    int lag = config.latency;

    vector<CacheLine>& set = sets[index];
    for (size_t i = 0; i < set.size(); ++i) {

        if (set[i].valid && set[i].tag == tag) {  // Cache hit

            ++hits;
            miss = false;
            
            set[i].dirty |= type == 'w';
            set[i].is_prefetched = false;
            policy->onHit(set, i, cycle);

            break;

        }  

    }
    
    if (miss) {  // Cache miss
        ++misses;

        int victim = -1;
        for (size_t i = 0; i < set.size(); ++i) {
            if (!set[i].valid) {
                victim = i;
                break;
            }
        }

        if (victim == -1) {
            victim = policy->getVictim(set);
            write_back_victim(set[victim], index, cycle);
            set[victim] = CacheLine();
        }

        set[victim].tag = tag;
        set[victim].valid = true;
        set[victim].dirty = type == 'w';
        policy->onMiss(set, victim, cycle);

        lag += next_level->access(addr, type, cycle);

    }

    // Prefetching
    auto prefetched = prefetcher->calculatePrefetch(addr, miss);
    for (auto& block: prefetched) {
        install_prefetch(block, cycle);
    }

    return lag;

}

void CacheLevel::install_prefetch(uint64_t addr, uint64_t cycle) {
    // TODO: Task 3
    // Implement a prefetch fill path similar to the miss path in access(), but
    // treat prefetched lines as clean and mark is_prefetched = true.
    // If you evict a dirty victim during prefetch installation, reuse
    // write_back_victim(...) instead of duplicating that logic.
    (void)addr;
    (void)cycle;

    uint64_t index = addr & ~((int64_t)-1 << index_bits);
    uint64_t tag = addr >> index_bits;
    vector<CacheLine>& set = sets[index];
    
    for (size_t i = 0; i < set.size(); ++i) {
        if (set[i].valid && set[i].tag == tag) {  // Already fetched
            return;
        }
    }

    ++prefetch_issued;
    int victim = -1;
    for (size_t i = 0; i < set.size(); ++i) {
        if (!set[i].valid) {
            victim = i;
            break;
        }
    }
    if (victim == -1) {
        victim = policy->getVictim(set);
        write_back_victim(set[victim], index, cycle);
        set[victim] = CacheLine();
    }

    set[victim].tag = tag;
    set[victim].valid = true;
    set[victim].dirty = false;
    set[victim].is_prefetched = true;
    policy->onMiss(set, victim, cycle);

    next_level->access(reconstruct_addr(tag, index), 'r', cycle);

}

void CacheLevel::printStats() {
    uint64_t total = hits + misses;
    cout << "  [" << level_name << "] "
         << "Hit Rate: " << fixed << setprecision(2) << (total ? (double)hits / total * 100.0 : 0) << "% "
         << "(Access: " << total << ", Miss: " << misses << ", WB: " << write_backs << ")" << endl;
    cout << "      Prefetches Issued: " << prefetch_issued << endl;
}
