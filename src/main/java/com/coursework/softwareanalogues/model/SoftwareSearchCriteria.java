package com.coursework.softwareanalogues.model;

public record SoftwareSearchCriteria(
        String query,
        Long categoryId,
        Long developerId,
        Boolean free
) {
    public static SoftwareSearchCriteria empty() {
        return new SoftwareSearchCriteria(null, null, null, null);
    }
}
