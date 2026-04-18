package com.coursework.softwareanalogues.model;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record Software(
        long softwareId,
        String title,
        String description,
        String systemRequirements,
        BigDecimal sizeMb,
        String website,
        Long categoryId,
        String categoryName,
        Long developerId,
        String developerName,
        boolean free,
        BigDecimal averageRating,
        long reviewCount,
        OffsetDateTime lastUpdatedAt
) {
}
