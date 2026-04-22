package com.coursework.softwareanalogues.dao.jdbc;

import com.coursework.softwareanalogues.config.ConnectionFactory;
import com.coursework.softwareanalogues.config.SqlQueries;
import com.coursework.softwareanalogues.dao.UserDao;
import com.coursework.softwareanalogues.exception.DatabaseException;
import com.coursework.softwareanalogues.model.User;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Optional;

public final class JdbcUserDao implements UserDao {
    private final ConnectionFactory connectionFactory;
    private final SqlQueries sqlQueries;

    public JdbcUserDao(ConnectionFactory connectionFactory, SqlQueries sqlQueries) {
        this.connectionFactory = connectionFactory;
        this.sqlQueries = sqlQueries;
    }

    @Override
    public Optional<User> authenticate(String username, String password) {
        // Поиск существующего пользователя в таблице users
        String sql = "SELECT user_id, username, display_name, is_active, created_at, last_login_at " +
                     "FROM software_app.users WHERE lower(username) = lower(?);";
        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            statement.setString(1, username);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    long userId = resultSet.getLong("user_id");
                    updateLastLogin(userId);
                    return Optional.of(mapUser(resultSet));
                }
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to fetch user metadata", e);
        }

        // Автоматическое создание записи для внешне аутентифицированного пользователя
        String insertSql = "INSERT INTO software_app.users (username, display_name, password_hash) " +
                           "VALUES (?, ?, 'externally_authenticated_db_user_placeholder') " +
                           "RETURNING user_id, username, display_name, is_active, created_at, last_login_at;";
        try (var statement = connectionFactory.getConnection().prepareStatement(insertSql)) {
            statement.setString(1, username);
            statement.setString(2, username);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    return Optional.of(mapUser(resultSet));
                }
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to auto-create user metadata", e);
        }
        return Optional.empty();
    }

    private void updateLastLogin(long userId) {
        // Обновление времени последнего входа
        String sql = "UPDATE software_app.users SET last_login_at = now() WHERE user_id = ?;";
        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            statement.setLong(1, userId);
            statement.executeUpdate();
        } catch (SQLException e) {
            // Игнорирование ошибки обновления как некритичной
        }
    }

    private User mapUser(ResultSet resultSet) throws SQLException {
        var createdAt = resultSet.getObject("created_at", java.time.OffsetDateTime.class);
        var lastLoginAt = resultSet.getObject("last_login_at", java.time.OffsetDateTime.class);
        return new User(
                resultSet.getLong("user_id"),
                resultSet.getString("username"),
                resultSet.getString("display_name"),
                resultSet.getBoolean("is_active"),
                createdAt,
                lastLoginAt
        );
    }
}
