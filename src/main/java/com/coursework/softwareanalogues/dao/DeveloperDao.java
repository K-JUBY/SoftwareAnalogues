package com.coursework.softwareanalogues.dao;

import com.coursework.softwareanalogues.model.Developer;

import java.util.List;

/** Provides read access to software developers. */
public interface DeveloperDao {
    /**
     * Returns all developers ordered by name.
     *
     * @return developer list
     */
    List<Developer> findAll();
    Developer create(String name, String website);
}
