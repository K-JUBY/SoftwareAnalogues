package com.coursework.softwareanalogues.model;

import java.time.OffsetDateTime;

public record UserCollection(
        long collectionId,
        long userId,
        String title,
        String description,
        long itemCount,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
