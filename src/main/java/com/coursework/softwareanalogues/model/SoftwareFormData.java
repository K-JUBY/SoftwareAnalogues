package com.coursework.softwareanalogues.model;

import java.math.BigDecimal;

public record SoftwareFormData(
        Long softwareId,
        String title,
        String description,
        String systemRequirements,
        BigDecimal sizeMb,
        String website,
        Long categoryId,
        Long developerId,
        boolean free
) {
}
