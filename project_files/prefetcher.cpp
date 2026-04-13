#include "prefetcher.h"

std::vector<uint64_t> NextLinePrefetcher::calculatePrefetch(uint64_t current_addr, bool miss) {
    (void)miss;
    return std::vector<uint64_t>{current_addr / block_size + 1};
}

std::vector<uint64_t> StridePrefetcher::calculatePrefetch(uint64_t current_addr, bool miss) {
    (void)miss;

    if (has_last_block) {
        uint64_t current_block = current_addr / block_size;
        int64_t stride = static_cast<int64_t>(current_block) - static_cast<int64_t>(last_block);
        if (stride == last_stride && stride != 0) {
            confidence++;
        } else {
            confidence = 0;
        }
        last_block = current_block;
        last_stride = stride;
    } else {
        has_last_block = true;
        last_block = current_addr / block_size;
        confidence = 0;
        last_stride = 0;
    }

    /*
    std::vector<uint64_t> prefetches;
    auto j = last_block;
    for (auto i = confidence; i > 1; --i) {
        j += last_stride;
        prefetches.push_back(j);
    }
    */

    // return prefetches;

    return confidence > 1 ? std::vector<uint64_t>{last_block + last_stride} : std::vector<uint64_t>{};

}

Prefetcher* createPrefetcher(std::string name, uint32_t block_size) {
    if (name == "NextLine") return new NextLinePrefetcher(block_size);
    if (name == "Stride") return new StridePrefetcher(block_size);
    return new NoPrefetcher();
}
