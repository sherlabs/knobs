#include "CSMC.h"
#include <IOKit/IOKitLib.h>
#include <string.h>

#define KERNEL_INDEX_SMC 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_WRITE_BYTES 6
#define SMC_CMD_READ_INDEX 8
#define SMC_CMD_READ_KEYINFO 9

typedef struct { char major, minor, build, reserved; uint16_t release; } SMCVers;
typedef struct { uint16_t version, length; uint32_t cpuPLimit, gpuPLimit, memPLimit; } SMCPLimit;
typedef struct { uint32_t dataSize, dataType; uint8_t dataAttributes; } SMCKeyInfo;
typedef struct {
    uint32_t key; SMCVers vers; SMCPLimit pLimit; SMCKeyInfo keyInfo;
    uint8_t result, status, data8; uint32_t data32; uint8_t bytes[32];
} SMCParam;

static io_connect_t conn = 0;

static uint32_t fourcc(const char *s) {
    return ((uint32_t)(uint8_t)s[0] << 24) | ((uint32_t)(uint8_t)s[1] << 16) |
           ((uint32_t)(uint8_t)s[2] << 8) | (uint32_t)(uint8_t)s[3];
}

int csmc_open(void) {
    if (conn) return 0;
    io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!svc) return -1;
    kern_return_t kr = IOServiceOpen(svc, mach_task_self(), 0, &conn);
    IOObjectRelease(svc);
    if (kr != KERN_SUCCESS) { conn = 0; return kr; }
    return 0;
}

void csmc_close(void) { if (conn) { IOServiceClose(conn); conn = 0; } }

static int call(SMCParam *in, SMCParam *out) {
    size_t outSize = sizeof(SMCParam);
    kern_return_t kr = IOConnectCallStructMethod(conn, KERNEL_INDEX_SMC, in, sizeof(SMCParam), out, &outSize);
    if (kr != KERN_SUCCESS) return kr;
    return out->result == 0 ? 0 : 1000 + out->result;
}

int csmc_read(const char *key, CSMCValue *v) {
    SMCParam in, out; memset(&in, 0, sizeof in); memset(&out, 0, sizeof out);
    in.key = fourcc(key); in.data8 = SMC_CMD_READ_KEYINFO;
    int r = call(&in, &out); if (r) return r;
    SMCKeyInfo info = out.keyInfo;
    memset(&in, 0, sizeof in); memset(&out, 0, sizeof out);
    in.key = fourcc(key); in.keyInfo.dataSize = info.dataSize; in.data8 = SMC_CMD_READ_BYTES;
    r = call(&in, &out); if (r) return r;
    v->key = in.key; v->dataSize = info.dataSize; v->dataType = info.dataType;
    memcpy(v->bytes, out.bytes, 32);
    return 0;
}

int csmc_write(const char *key, const uint8_t *bytes, uint32_t size) {
    CSMCValue cur; int r = csmc_read(key, &cur); if (r) return r;
    if (size != cur.dataSize) return 2000;   // refuse mismatched sizes
    SMCParam in, out; memset(&in, 0, sizeof in); memset(&out, 0, sizeof out);
    in.key = fourcc(key); in.data8 = SMC_CMD_WRITE_BYTES; in.keyInfo.dataSize = size;
    memcpy(in.bytes, bytes, size > 32 ? 32 : size);
    return call(&in, &out);
}

int csmc_key_count(uint32_t *count) {
    CSMCValue v; int r = csmc_read("#KEY", &v); if (r) return r;
    *count = ((uint32_t)v.bytes[0] << 24) | ((uint32_t)v.bytes[1] << 16) | ((uint32_t)v.bytes[2] << 8) | v.bytes[3];
    return 0;
}

int csmc_key_at(uint32_t index, char out5[5]) {
    SMCParam in, out; memset(&in, 0, sizeof in); memset(&out, 0, sizeof out);
    in.data8 = SMC_CMD_READ_INDEX; in.data32 = index;
    int r = call(&in, &out); if (r) return r;
    out5[0] = out.key >> 24; out5[1] = out.key >> 16; out5[2] = out.key >> 8; out5[3] = out.key; out5[4] = 0;
    return 0;
}
