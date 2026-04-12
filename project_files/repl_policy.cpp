#include "repl_policy.h"

// =========================================================
// TODO: Task 1 / Task 3 replacement policies
// Implement LRU first, then extend with SRRIP / BIP.
// =========================================================

void LRUPolicy::onHit(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    set[way].last_access = cycle;
}

void LRUPolicy::onMiss(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    set[way].last_access = cycle;
}

int LRUPolicy::getVictim(std::vector<CacheLine>& set) {
    int lru = 0;
    for (size_t i = 0; i < set.size(); ++i) {
        if (!set[i].valid) return i;
        else lru = (set[i].last_access < set[lru].last_access) ? i : lru;
    }
    return lru;
}

void SRRIPPolicy::onHit(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    (void)set;
    (void)way;
    (void)cycle;
    // TODO: typically promote the line to RRPV=0.
}

void SRRIPPolicy::onMiss(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    (void)set;
    (void)way;
    (void)cycle;
    // TODO: insert with a long re-reference interval, e.g. RRPV=2.
}

int SRRIPPolicy::getVictim(std::vector<CacheLine>& set) {
    (void)set;
    // TODO: search for RRPV==3, otherwise age all lines and retry.
    return 0;
}

void BIPPolicy::onHit(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    (void)set;
    (void)way;
    (void)cycle;
    // TODO: hits still become MRU.
}

void BIPPolicy::onMiss(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    (void)set;
    (void)way;
    (void)cycle;
    // TODO: mostly insert at LRU position, but occasionally insert at MRU.
    // Hint: use insertion_counter and throttle.
}

int BIPPolicy::getVictim(std::vector<CacheLine>& set) {
    (void)set;
    // TODO: BIP usually uses the same victim selection as LRU.
    return 0;
}

ReplacementPolicy* createReplacementPolicy(std::string name) {
    if (name == "SRRIP") return new SRRIPPolicy();
    if (name == "BIP") return new BIPPolicy();
    return new LRUPolicy();
}
