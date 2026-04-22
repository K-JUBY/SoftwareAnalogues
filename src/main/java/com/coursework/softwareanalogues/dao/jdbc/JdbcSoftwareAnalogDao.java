package com.coursework.softwareanalogues.dao.jdbc;

import com.coursework.softwareanalogues.config.ConnectionFactory;
import com.coursework.softwareanalogues.config.SqlQueries;
import com.coursework.softwareanalogues.dao.SoftwareAnalogDao;
import com.coursework.softwareanalogues.exception.DatabaseException;
import com.coursework.softwareanalogues.model.SoftwareAnalog;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

public final class JdbcSoftwareAnalogDao implements SoftwareAnalogDao {
    private final ConnectionFactory connectionFactory;
    private final SqlQueries sqlQueries;

    public JdbcSoftwareAnalogDao(ConnectionFactory connectionFactory, SqlQueries sqlQueries) {
        this.connectionFactory = connectionFactory;
        this.sqlQueries = sqlQueries;
    }

    @Override
    public List<SoftwareAnalog> findBySoftwareId(long softwareId) {
        // Загрузка аналогов для конкретного ПО
        List<SoftwareAnalog> analogs = new ArrayList<>();
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("analog.findBySoftware"))) {
            statement.setLong(1, softwareId);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    analogs.add(mapAnalog(resultSet));
                }
            }
            return analogs;
        } catch (SQLException e) {
            throw new DatabaseException("Failed to load software analogues", e);
        }
    }

    @Override
    public void add(long softwareId, long analogId, String reason, Short similarityScore) {
        // Добавление связи аналога с ПО
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("analog.add"))) {
            statement.setLong(1, softwareId);
            statement.setLong(2, analogId);
            statement.setString(3, reason);
            // Обработка nullable параметра similarityScore
            if (similarityScore == null) {
                statement.setNull(4, Types.SMALLINT);
            } else {
                statement.setShort(4, similarityScore);
            }
            statement.execute();
        } catch (SQLException e) {
            throw new DatabaseException("Failed to add software analogue", e);
        }
    }

    @Override
    public void remove(long softwareId, long analogId) {
        // Удаление связи аналога с ПО
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("analog.remove"))) {
            statement.setLong(1, softwareId);
            statement.setLong(2, analogId);
            statement.execute();
        } catch (SQLException e) {
            throw new DatabaseException("Failed to remove software analogue", e);
        }
    }

    // Маппинг ResultSet в объект SoftwareAnalog
    private SoftwareAnalog mapAnalog(ResultSet resultSet) throws SQLException {
        short score = resultSet.getShort("similarity_score");
        boolean scoreWasNull = resultSet.wasNull();
        // Обработка nullable поля similarity_score
        return new SoftwareAnalog(
                resultSet.getLong("software_analog_id"),
                resultSet.getLong("software_id"),
                resultSet.getLong("analog_id"),
                resultSet.getString("analog_title"),
                resultSet.getString("category_name"),
                resultSet.getString("developer_name"),
                resultSet.getBoolean("is_free"),
                resultSet.getBigDecimal("average_rating"),
                resultSet.getLong("review_count"),
                resultSet.getString("reason"),
                scoreWasNull ? null : score,
                resultSet.getObject("created_at", java.time.OffsetDateTime.class)
        );
    }
}
