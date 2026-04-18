package com.coursework.softwareanalogues.model;

import java.time.OffsetDateTime;

public record User(
        long userId,
        String username,
        String displayName,
        boolean active,
        OffsetDateTime createdAt,
        OffsetDateTime lastLoginAt
) {
}
