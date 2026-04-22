package com.coursework.softwareanalogues.dao;

import com.coursework.softwareanalogues.model.Software;
import com.coursework.softwareanalogues.model.SoftwareFormData;
import com.coursework.softwareanalogues.model.SoftwareSearchCriteria;

import java.util.List;

/** Provides catalogue access to software records. */
public interface SoftwareDao {
    /**
     * Searches software using database-side function `search_software`.
     *
     * @param criteria search and filter values
     * @return matching software records
     */
    List<Software> search(SoftwareSearchCriteria criteria);

    /**
     * Creates a software record through a database-side function.
     *
     * @param data software form data
     * @return created software id
     */
    long create(SoftwareFormData data);

    /**
     * Updates an existing software record through a database-side function.
     *
     * @param data software form data with id
     */
    void update(SoftwareFormData data);

    /**
     * Deletes a software record by id.
     *
     * @param softwareId software id
     */
    void deleteById(long softwareId);
}
