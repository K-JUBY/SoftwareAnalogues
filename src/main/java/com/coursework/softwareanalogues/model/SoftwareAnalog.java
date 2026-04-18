package com.coursework.softwareanalogues.model;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record SoftwareAnalog(
        long softwareAnalogId,
        long softwareId,
        long analogId,
        String analogTitle,
        String categoryName,
        String developerName,
        boolean free,
        BigDecimal averageRating,
        long reviewCount,
        String reason,
        Short similarityScore,
        OffsetDateTime createdAt
) {
}
