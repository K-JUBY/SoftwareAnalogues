package com.coursework.softwareanalogues.dao.jdbc;

import com.coursework.softwareanalogues.config.ConnectionFactory;
import com.coursework.softwareanalogues.config.SqlQueries;
import com.coursework.softwareanalogues.dao.CollectionDao;
import com.coursework.softwareanalogues.exception.DatabaseException;
import com.coursework.softwareanalogues.model.CollectionItem;
import com.coursework.softwareanalogues.model.UserCollection;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

public final class JdbcCollectionDao implements CollectionDao {
    private final ConnectionFactory connectionFactory;
    private final SqlQueries sqlQueries;

    public JdbcCollectionDao(ConnectionFactory connectionFactory, SqlQueries sqlQueries) {
        this.connectionFactory = connectionFactory;
        this.sqlQueries = sqlQueries;
    }

    @Override
    public List<UserCollection> findCurrentUserCollections() {
        // Загрузка коллекций текущего пользователя
        List<UserCollection> collections = new ArrayList<>();
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("collection.findCurrentUser"));
             ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                collections.add(mapCollection(resultSet));
            }
            return collections;
        } catch (SQLException e) {
            throw new DatabaseException("Failed to load collections", e);
        }
    }

    @Override
    public long create(String title, String description) {
        // Создание новой коллекции в БД
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("collection.create"))) {
            statement.setString(1, title);
            statement.setString(2, description);
            try (ResultSet resultSet = statement.executeQuery()) {
                resultSet.next();
                // Возврат ID созданной коллекции
                return resultSet.getLong(1);
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to create collection", e);
        }
    }

    @Override
    public void deleteById(long collectionId) {
        // Удаление коллекции из БД
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("collection.delete"))) {
            statement.setLong(1, collectionId);
            statement.execute();
        } catch (SQLException e) {
            throw new DatabaseException("Failed to delete collection", e);
        }
    }

    @Override
    public List<CollectionItem> findItems(long collectionId) {
        // Загрузка элементов коллекции
        List<CollectionItem> items = new ArrayList<>();
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("collection.items"))) {
            statement.setLong(1, collectionId);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    items.add(mapItem(resultSet));
                }
            }
            return items;
        } catch (SQLException e) {
            throw new DatabaseException("Failed to load collection items", e);
        }
    }

    @Override
    public long addItem(long collectionId, long softwareId, String note, Integer position) {
        // Добавление элемента в коллекцию
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("collection.item.add"))) {
            statement.setLong(1, collectionId);
            statement.setLong(2, softwareId);
            statement.setString(3, note);
            // Обработка nullable параметра position
            if (position == null) {
                statement.setNull(4, Types.INTEGER);
            } else {
                statement.setInt(4, position);
            }
            try (ResultSet resultSet = statement.executeQuery()) {
                resultSet.next();
                // Возврат ID созданного элемента коллекции
                return resultSet.getLong(1);
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to add collection item", e);
        }
    }

    @Override
    public void removeItem(long collectionId, long softwareId) {
        // Удаление элемента из коллекции
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("collection.item.remove"))) {
            statement.setLong(1, collectionId);
            statement.setLong(2, softwareId);
            statement.execute();
        } catch (SQLException e) {
            throw new DatabaseException("Failed to remove collection item", e);
        }
    }

    // Маппинг ResultSet в объект UserCollection
    private UserCollection mapCollection(ResultSet resultSet) throws SQLException {
        return new UserCollection(
                resultSet.getLong("collection_id"),
                resultSet.getLong("user_id"),
                resultSet.getString("title"),
                resultSet.getString("description"),
                resultSet.getLong("item_count"),
                resultSet.getObject("created_at", java.time.OffsetDateTime.class),
                resultSet.getObject("updated_at", java.time.OffsetDateTime.class)
        );
    }

    // Маппинг ResultSet в объект CollectionItem
    private CollectionItem mapItem(ResultSet resultSet) throws SQLException {
        int position = resultSet.getInt("item_position");
        // Обработка nullable поля item_position
        return new CollectionItem(
                resultSet.getLong("collection_item_id"),
                resultSet.getLong("collection_id"),
                resultSet.getLong("software_id"),
                resultSet.getString("title"),
                resultSet.getString("category_name"),
                resultSet.getString("developer_name"),
                resultSet.getBoolean("is_free"),
                resultSet.getString("note"),
                resultSet.wasNull() ? null : position,
                resultSet.getObject("added_at", java.time.OffsetDateTime.class)
        );
    }
}
