package com.coursework.softwareanalogues.dao;

import com.coursework.softwareanalogues.model.Category;
import com.coursework.softwareanalogues.model.CategoryCount;

import java.util.List;

/** Provides read access to software categories. */
public interface CategoryDao {
    /**
     * Returns all categories ordered by name.
     *
     * @return category list
     */
    List<Category> findAll();
    List<CategoryCount> getCategoryCounts();
    Category create(String name, String description);
}
