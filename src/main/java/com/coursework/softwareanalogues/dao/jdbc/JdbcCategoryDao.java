package com.coursework.softwareanalogues.dao.jdbc;

import com.coursework.softwareanalogues.config.ConnectionFactory;
import com.coursework.softwareanalogues.config.SqlQueries;
import com.coursework.softwareanalogues.dao.CategoryDao;
import com.coursework.softwareanalogues.exception.DatabaseException;
import com.coursework.softwareanalogues.model.Category;
import com.coursework.softwareanalogues.model.CategoryCount;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public final class JdbcCategoryDao implements CategoryDao {
    private final ConnectionFactory connectionFactory;
    private final SqlQueries sqlQueries;

    public JdbcCategoryDao(ConnectionFactory connectionFactory, SqlQueries sqlQueries) {
        this.connectionFactory = connectionFactory;
        this.sqlQueries = sqlQueries;
    }

    @Override
    public List<Category> findAll() {
        String sql = sqlQueries.get("category.findAll");
        List<Category> categories = new ArrayList<>();

        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            // Передача текущей локали для перевода названий
            statement.setString(1, java.util.Locale.getDefault().getLanguage());
            
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    categories.add(new Category(
                            resultSet.getLong("category_id"),
                            resultSet.getString("name"),
                            resultSet.getString("description")
                    ));
                }
                return categories;
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to load categories", e);
        }
    }

    @Override
    public List<CategoryCount> getCategoryCounts() {
        String sql = sqlQueries.get("category.getCategoryCounts");
        List<CategoryCount> counts = new ArrayList<>();

        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            // Локализация названий категорий через JOIN с translations
            statement.setString(1, java.util.Locale.getDefault().getLanguage());
            
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    counts.add(new CategoryCount(
                            resultSet.getString("category_name"),
                            resultSet.getLong("software_count")
                    ));
                }
                return counts;
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to load category counts", e);
        }
    }

    @Override
    public Category create(String name, String description) {
        // Создание новой категории с возвратом сгенерированного ID
        String sql = "INSERT INTO software_app.categories (name, description) VALUES (?, ?) RETURNING category_id, name, description";
        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            statement.setString(1, name);
            statement.setString(2, description);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    return new Category(
                            resultSet.getLong("category_id"),
                            resultSet.getString("name"),
                            resultSet.getString("description")
                    );
                }
                throw new DatabaseException("Failed to create category");
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to create category", e);
        }
    }
}
