/* Copyright 2022 Winterbloom LLC & Alethea Katherine Flowers

Use of this source code is governed by an MIT-style
license that can be found in the LICENSE.md file or at
https://opensource.org/licenses/MIT. */

#ifdef __cplusplus
extern "C" {
#endif

#pragma once

#include "graviton.h"
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define PHASON_PROTOCOL_ID 0xA1
#define PHASON_CONTROLLER_ADDRESS 0x00
#define PHASON_MAX_FEEDER_ADDRESS 0x80
#define PHASON_LOGICAL_ADDRESS 0xFF
#define PHASON_UID_SIZE 12

#define PHASON_ASSERT_PAYLOAD_SIZE(typename)                                                                           \
    static_assert(sizeof(typename) == GRAVITON_PAYLOAD_SIZE, #typename "must be fit in Graviton datagram payload");

enum PhasonStatusCode {
    // All is good. :)
    PHASON_OK = 0,
    // General error code, use only when other codes don't apply.
    PHASON_ERROR = 1,
    // Unknown or malformed request.
    PHASON_INVALID_REQUEST = 2,
    // An issue occurred with the motor.
    PHASON_MOTOR_ERROR = 3,
    // Not ready to response. Retry the request after a delay.
    PHASON_NOT_READY = 4,
};

struct PhasonRequest {
    uint8_t command;  // MSB always clear.
    uint8_t data[25];
} __attribute__((packed));

PHASON_ASSERT_PAYLOAD_SIZE(struct PhasonRequest);

struct PhasonResponse {
    uint8_t command;  // MSB always set.
    uint8_t status;
    uint8_t data[24];
} __attribute__((packed));

PHASON_ASSERT_PAYLOAD_SIZE(struct PhasonResponse);

inline static struct GravitonDatagram PhasonRequest_to_datagram(uint8_t feeder_addr, void* req) {
    struct GravitonDatagram datagram;
    GravitonDatagram_init(&datagram, PHASON_CONTROLLER_ADDRESS, feeder_addr, PHASON_PROTOCOL_ID);
    memcpy(datagram.payload, (uint8_t*)(req), GRAVITON_PAYLOAD_SIZE);
    GravitonDatagram_set_crc8(&datagram);
    return datagram;
}

inline static struct GravitonDatagram PhasonResponse_to_datagram(uint8_t feeder_addr, void* resp) {
    struct GravitonDatagram datagram;
    GravitonDatagram_init(&datagram, feeder_addr, PHASON_CONTROLLER_ADDRESS, PHASON_PROTOCOL_ID);
    memcpy(datagram.payload, (uint8_t*)(resp), GRAVITON_PAYLOAD_SIZE);
    GravitonDatagram_set_crc8(&datagram);
    return datagram;
}

#define __PHASON_FROM_DATAGRAM(response_type)                                                                          \
    inline static struct response_type* response_type##_from_datagram(struct GravitonDatagram* datagram) {             \
        return ((struct response_type*)(datagram->payload));                                                           \
    }

enum PhasonCommands {
    PHASON_GET_FEEDER_INFO_REQ = 0x01,
    PHASON_GET_FEEDER_INFO_RESP = 0x81,
    PHASON_RESET_FEEDER_REQ = 0x02,
    PHASON_RESET_FEEDER_RESP = 0x82,
    PHASON_START_FEED_REQ = 0x03,
    PHASON_START_FEED_RESP = 0x83,
    PHASON_FEED_STATUS_REQ = 0x04,
    PHASON_FEED_STATUS_RESP = 0x84,
    PHASON_QUERY_BY_UID_REQ = 0x04,
    PHASON_QUERY_BY_UID_RESP = 0x84,
};

struct PhasonGetFeederInfoResponse {
    uint8_t command;  // Always 0x81
    uint8_t status;
    uint8_t protocol_version;
    uint8_t firmware_year;
    uint8_t firmware_month;
    uint8_t firmware_day;
    uint8_t uid[12];
    uint8_t padding[8];
} __attribute__((packed));

PHASON_ASSERT_PAYLOAD_SIZE(struct PhasonGetFeederInfoResponse);
__PHASON_FROM_DATAGRAM(PhasonGetFeederInfoResponse);

struct PhasonStartFeedRequest {
    uint8_t command;  // Always 0x03
    uint8_t sequence;
    int32_t micrometers;
    uint8_t padding[20];
} __attribute__((packed));

PHASON_ASSERT_PAYLOAD_SIZE(struct PhasonStartFeedRequest);

struct PhasonStartFeedResponse {
    uint8_t command;  // Always 0x83
    uint8_t status;
    uint8_t sequence;
    uint8_t padding[23];
} __attribute__((packed));

PHASON_ASSERT_PAYLOAD_SIZE(struct PhasonStartFeedResponse);
__PHASON_FROM_DATAGRAM(PhasonStartFeedResponse);

struct PhasonFeedStatusRequest {
    uint8_t command;  // Always 0x04
    uint8_t sequence;
    uint8_t padding[24];
} __attribute__((packed));

PHASON_ASSERT_PAYLOAD_SIZE(struct PhasonFeedStatusRequest);

struct PhasonFeedStatusResponse {
    uint8_t command;  // Always 0x84
    uint8_t status;
    uint8_t sequence;
    int32_t actual_micrometers;
    uint8_t padding[19];
} __attribute__((packed));

PHASON_ASSERT_PAYLOAD_SIZE(struct PhasonFeedStatusResponse);
__PHASON_FROM_DATAGRAM(PhasonFeedStatusResponse);

struct PhasonQueryByUIDRequest {
    uint8_t command;  // Always 0x1F
    uint8_t uid[12];
    uint8_t padding[13];
} __attribute__((packed));

PHASON_ASSERT_PAYLOAD_SIZE(struct PhasonQueryByUIDRequest);

#ifdef __cplusplus
}
#endif
