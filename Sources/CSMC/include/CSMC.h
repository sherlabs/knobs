#ifndef CSMC_H
#define CSMC_H
#include <stdint.h>
#include <stdbool.h>

/// Minimal AppleSMC user-client wrapper (read path). Written from the publicly
/// documented AppleSMC struct layout; contains no third-party code.
typedef struct {
    uint32_t key;          // four-char code, big endian
    uint32_t dataSize;
    uint32_t dataType;     // four-char code
    uint8_t  bytes[32];
} CSMCValue;

int  csmc_open(void);                              // 0 on success, else kern_return_t
void csmc_close(void);
int  csmc_read(const char *key, CSMCValue *out);   // 0 on success
int  csmc_write(const char *key, const uint8_t *bytes, uint32_t size);  // needs root
int  csmc_key_count(uint32_t *count);              // number of SMC keys
int  csmc_key_at(uint32_t index, char out[5]);     // name of key by index
#endif
