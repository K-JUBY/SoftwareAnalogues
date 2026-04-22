package com.coursework.softwareanalogues.dao;

import com.coursework.softwareanalogues.model.Review;

import java.util.List;

/** Provides access to software reviews. */
public interface ReviewDao {
    List<Review> findBySoftwareId(long softwareId);

    long create(long softwareId, String text, int rating);
}
