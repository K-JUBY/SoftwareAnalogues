package com.coursework.softwareanalogues.model;

public record Screenshot(
        long screenshotId,
        long softwareId,
        byte[] imageData,
        String mimeType,
        String caption
) {
}
