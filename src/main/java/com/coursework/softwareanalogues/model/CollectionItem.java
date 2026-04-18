package com.coursework.softwareanalogues.model;

import java.time.OffsetDateTime;

public record CollectionItem(
        long collectionItemId,
        long collectionId,
        long softwareId,
        String title,
        String categoryName,
        String developerName,
        boolean free,
        String note,
        Integer position,
        OffsetDateTime addedAt
) {
}
