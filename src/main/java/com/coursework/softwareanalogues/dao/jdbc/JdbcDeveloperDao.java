package com.coursework.softwareanalogues.dao.jdbc;

import com.coursework.softwareanalogues.config.ConnectionFactory;
import com.coursework.softwareanalogues.config.SqlQueries;
import com.coursework.softwareanalogues.dao.DeveloperDao;
import com.coursework.softwareanalogues.exception.DatabaseException;
import com.coursework.softwareanalogues.model.Developer;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public final class JdbcDeveloperDao implements DeveloperDao {
    private final ConnectionFactory connectionFactory;
    private final SqlQueries sqlQueries;

    public JdbcDeveloperDao(ConnectionFactory connectionFactory, SqlQueries sqlQueries) {
        this.connectionFactory = connectionFactory;
        this.sqlQueries = sqlQueries;
    }

    @Override
    public List<Developer> findAll() {
        // Загрузка всех разработчиков из БД
        List<Developer> developers = new ArrayList<>();

        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("developer.findAll"));
             ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                // Маппинг результата в объект Developer
                developers.add(new Developer(
                        resultSet.getLong("developer_id"),
                        resultSet.getString("name"),
                        resultSet.getString("website")
                ));
            }
            return developers;
        } catch (SQLException e) {
            throw new DatabaseException("Failed to load developers", e);
        }
    }

    @Override
    public Developer create(String name, String website) {
        // Создание нового разработчика в БД
        String sql = "INSERT INTO software_app.developers (name, website) VALUES (?, ?) RETURNING developer_id, name, website";
        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            statement.setString(1, name);
            statement.setString(2, website);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    // Возврат созданного объекта Developer
                    return new Developer(
                            resultSet.getLong("developer_id"),
                            resultSet.getString("name"),
                            resultSet.getString("website")
                    );
                }
                throw new DatabaseException("Failed to create developer");
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to create developer", e);
        }
    }
}
