package com.coursework.softwareanalogues.model;

import java.time.OffsetDateTime;

public record Review(
        long reviewId,
        long softwareId,
        Long userId,
        String authorName,
        String reviewText,
        int rating,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
