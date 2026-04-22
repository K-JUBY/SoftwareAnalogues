package com.coursework.softwareanalogues.dao;

import com.coursework.softwareanalogues.model.SoftwareAnalog;

import java.util.List;

/** Provides access to software analogue links. */
public interface SoftwareAnalogDao {
    List<SoftwareAnalog> findBySoftwareId(long softwareId);

    void add(long softwareId, long analogId, String reason, Short similarityScore);

    void remove(long softwareId, long analogId);
}
