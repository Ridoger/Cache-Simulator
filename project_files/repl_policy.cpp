#include "repl_policy.h"

void LRUPolicy::onHit(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    set[way].last_access = cycle;
}

void LRUPolicy::onMiss(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    set[way].last_access = cycle;
}

int LRUPolicy::getVictim(std::vector<CacheLine>& set) {
    int lru = 0;
    for (size_t i = 1; i < set.size(); ++i) {
        lru = (set[i].last_access < set[lru].last_access) ? i : lru;
    }
    return lru;
}

void SRRIPPolicy::onHit(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    set[way].rrpv = 0;
}

void SRRIPPolicy::onMiss(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    set[way].rrpv = 2;
}

int SRRIPPolicy::getVictim(std::vector<CacheLine>& set) {
    while (true) {
        for (size_t i = 0; i < set.size(); ++i) {
            if (set[i].rrpv == 3) {
                return i;
            }
        }
        for (size_t i = 0; i < set.size(); ++set[i++].rrpv) {}
    }
}

void BIPPolicy::onHit(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    set[way].last_access = cycle;
}

void BIPPolicy::onMiss(std::vector<CacheLine>& set, int way, uint64_t cycle) {
    ++insertion_counter;
    set[way].last_access = cycle;
}

int BIPPolicy::getVictim(std::vector<CacheLine>& set) {
    int lru = 0;
    int mru = 0;
    for (size_t i = 1; i < set.size(); ++i) {
        lru = (set[i].last_access < set[lru].last_access) ? i : lru;
        mru = (set[i].last_access > set[mru].last_access) ? i : mru;
    }

    if ((insertion_counter + 1) % throttle == 0) {
        return lru;
    }
    return mru;
}

ReplacementPolicy* createReplacementPolicy(std::string name) {
    if (name == "SRRIP") return new SRRIPPolicy();
    if (name == "BIP") return new BIPPolicy();
    return new LRUPolicy();
}
