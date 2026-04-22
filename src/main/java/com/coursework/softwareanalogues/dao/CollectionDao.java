package com.coursework.softwareanalogues.dao;

import com.coursework.softwareanalogues.model.CollectionItem;
import com.coursework.softwareanalogues.model.UserCollection;

import java.util.List;

/** Provides access to the current user's collections. */
public interface CollectionDao {
    List<UserCollection> findCurrentUserCollections();

    long create(String title, String description);

    void deleteById(long collectionId);

    List<CollectionItem> findItems(long collectionId);

    long addItem(long collectionId, long softwareId, String note, Integer position);

    void removeItem(long collectionId, long softwareId);
}
