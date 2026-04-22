package com.coursework.softwareanalogues.dao;

import com.coursework.softwareanalogues.model.Screenshot;
import java.util.List;

public interface ScreenshotDao {
    List<Screenshot> findBySoftwareId(long softwareId);
    long create(long softwareId, byte[] imageData, String mimeType, String caption);
    void delete(long screenshotId);
}
