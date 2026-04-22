package com.coursework.softwareanalogues.dao.jdbc;

import com.coursework.softwareanalogues.config.ConnectionFactory;
import com.coursework.softwareanalogues.config.SqlQueries;
import com.coursework.softwareanalogues.dao.SoftwareDao;
import com.coursework.softwareanalogues.exception.DatabaseException;
import com.coursework.softwareanalogues.model.Software;
import com.coursework.softwareanalogues.model.SoftwareFormData;
import com.coursework.softwareanalogues.model.SoftwareSearchCriteria;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

public final class JdbcSoftwareDao implements SoftwareDao {
    private final ConnectionFactory connectionFactory;
    private final SqlQueries sqlQueries;

    public JdbcSoftwareDao(ConnectionFactory connectionFactory, SqlQueries sqlQueries) {
        this.connectionFactory = connectionFactory;
        this.sqlQueries = sqlQueries;
    }

    @Override
    public List<Software> search(SoftwareSearchCriteria criteria) {
        String sql = sqlQueries.get("software.search");
        List<Software> software = new ArrayList<>();

        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            // Параметр поискового запроса
            statement.setString(1, criteria.query());
            // Фильтр по категории
            if (criteria.categoryId() == null) {
                statement.setNull(2, Types.BIGINT);
            } else {
                statement.setLong(2, criteria.categoryId());
            }
            // Фильтр по разработчику
            if (criteria.developerId() == null) {
                statement.setNull(3, Types.BIGINT);
            } else {
                statement.setLong(3, criteria.developerId());
            }
            // Фильтр по типу лицензии
            if (criteria.free() == null) {
                statement.setNull(4, Types.BOOLEAN);
            } else {
                statement.setBoolean(4, criteria.free());
            }
            // Текущая локаль для перевода названий категорий
            statement.setString(5, java.util.Locale.getDefault().getLanguage());

            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    software.add(mapSoftware(resultSet));
                }
            }
            return software;
        } catch (SQLException e) {
            throw new DatabaseException("Software search failed", e);
        }
    }

    @Override
    public long create(SoftwareFormData data) {
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("software.create"))) {
            // Заполнение параметров формы
            setFormParameters(statement, data, 1);
            // Вызов INSERT RETURNING software_id
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    return resultSet.getLong(1);
                }
                throw new DatabaseException("Software creation did not return id", null);
            }
        } catch (SQLException e) {
            throw new DatabaseException("Software creation failed", e);
        }
    }

    @Override
    public void update(SoftwareFormData data) {
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("software.update"))) {
            // Проверка наличия ID для обновления
            if (data.softwareId() == null) {
                throw new DatabaseException("Software id is required for update", null);
            }
            statement.setLong(1, data.softwareId());
            // Заполнение параметров формы
            setFormParameters(statement, data, 2);
            statement.execute();
        } catch (SQLException e) {
            throw new DatabaseException("Software update failed", e);
        }
    }

    @Override
    public void deleteById(long softwareId) {
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("software.delete"))) {
            statement.setLong(1, softwareId);
            statement.execute();
        } catch (SQLException e) {
            throw new DatabaseException("Software deletion failed", e);
        }
    }

    private Software mapSoftware(ResultSet resultSet) throws SQLException {
        // Обработка nullable полей для категории
        long categoryId = resultSet.getLong("category_id");
        Long category = resultSet.wasNull() ? null : categoryId;
        // Обработка nullable полей для разработчика
        long developerId = resultSet.getLong("developer_id");
        Long developer = resultSet.wasNull() ? null : developerId;

        return new Software(
                resultSet.getLong("software_id"),
                resultSet.getString("title"),
                resultSet.getString("description"),
                resultSet.getString("system_requirements"),
                resultSet.getBigDecimal("size_mb"),
                resultSet.getString("website"),
                category,
                resultSet.getString("category_name"),
                developer,
                resultSet.getString("developer_name"),
                resultSet.getBoolean("is_free"),
                resultSet.getBigDecimal("average_rating"),
                resultSet.getLong("review_count"),
                resultSet.getObject("last_updated_at", java.time.OffsetDateTime.class)
        );
    }

    private void setFormParameters(java.sql.PreparedStatement statement, SoftwareFormData data, int startIndex)
            throws SQLException {
        // Основные поля программы
        statement.setString(startIndex, data.title());
        statement.setString(startIndex + 1, data.description());
        statement.setString(startIndex + 2, data.systemRequirements());
        statement.setBigDecimal(startIndex + 3, data.sizeMb());
        statement.setString(startIndex + 4, data.website());
        // Внешний ключ на категорию
        if (data.categoryId() == null) {
            statement.setNull(startIndex + 5, Types.BIGINT);
        } else {
            statement.setLong(startIndex + 5, data.categoryId());
        }
        // Внешний ключ на разработчика
        if (data.developerId() == null) {
            statement.setNull(startIndex + 6, Types.BIGINT);
        } else {
            statement.setLong(startIndex + 6, data.developerId());
        }
        // Флаг бесплатности
        statement.setBoolean(startIndex + 7, data.free());
    }
}
