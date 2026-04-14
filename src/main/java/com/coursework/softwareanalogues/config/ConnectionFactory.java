package com.coursework.softwareanalogues.config;

import com.coursework.softwareanalogues.exception.DatabaseException;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;

/**
 * Фабрика соединений с базой данных.
 * Управляет жизненным циклом активного подключения к PostgreSQL,
 * поддерживает динамическое подключение с логином и паролем пользователя
 * и выполняет регистрацию пользователей с разграничением привилегий (DCL).
 */
public final class ConnectionFactory implements AutoCloseable {
    private final DatabaseConfig config;
    private final SqlQueries sqlQueries;
    private Connection connection;
    private String username;
    private String password;

    /**
     * Конструктор фабрики соединений.
     *
     * @param config конфигурация подключения к БД
     * @param sqlQueries объект с внешними SQL-запросами
     */
    public ConnectionFactory(DatabaseConfig config, SqlQueries sqlQueries) {
        this.config = config;
        this.sqlQueries = sqlQueries;
    }

    /**
     * Инициализирует новое соединение с БД с переданными учетными данными.
     * Закрывает предыдущее соединение, если оно было открыто.
     *
     * @param username логин пользователя СУБД
     * @param password пароль пользователя СУБД
     * @throws SQLException в случае ошибки подключения
     */
    public void initConnection(String username, String password) throws SQLException {
        // Закрытие предыдущего соединения
        if (connection != null && !connection.isClosed()) {
            connection.close();
        }
        // Сохранение креденшиалов для переподключения
        this.username = username;
        this.password = password;
        // Установка нового соединения
        this.connection = DriverManager.getConnection(config.url(), username, password);
    }

    /**
     * Возвращает активное соединение с базой данных.
     * Если соединение закрыто, пытается восстановить его по сохраненным креденшиалам.
     *
     * @return активное соединение Connection
     */
    public Connection getConnection() {
        try {
            // Проверка активности соединения
            if (connection == null || connection.isClosed()) {
                if (username == null || password == null) {
                    throw new SQLException("Connection is not initialized. Please authenticate first.");
                }
                // Переподключение с сохраненными креденшиалами
                connection = DriverManager.getConnection(config.url(), username, password);
            }
            return connection;
        } catch (SQLException e) {
            throw new DatabaseException("Database connection failed", e);
        }
    }

    public void setCurrentAppUser(long userId) {
        // Установка переменной current_user_id в сессии PostgreSQL
        try (PreparedStatement statement = getConnection().prepareStatement(sqlQueries.get("session.setCurrentUser"))) {
            statement.setString(1, Long.toString(userId));
            statement.executeQuery();
        } catch (SQLException e) {
            throw new DatabaseException("Failed to set current application user", e);
        }
    }

    public void registerUser(String username, String password) throws SQLException {
        // Валидация формата логина
        if (!username.matches("^[a-zA-Z0-9_]{3,30}$")) {
            throw new IllegalArgumentException("Invalid username format");
        }
        
        // Подключение с правами администратора
        try (Connection systemConn = DriverManager.getConnection(config.url(), config.username(), config.password());
             java.sql.Statement stmt = systemConn.createStatement()) {
             
            // Экранирование одинарных кавычек в пароле
            String escapedPassword = "'" + password.replace("'", "''") + "'";
            // Удаление существующей роли
            String dropRoleSql = String.format("DROP ROLE IF EXISTS \"%s\";", username);
            stmt.executeUpdate(dropRoleSql);
            
            // Создание новой роли с правом входа
            String createRoleSql = String.format("CREATE ROLE \"%s\" WITH LOGIN PASSWORD %s;", username, escapedPassword);
            stmt.executeUpdate(createRoleSql);
            
            // Предоставление прав на схему
            String grantSchemaSql = String.format("GRANT ALL ON SCHEMA software_app TO \"%s\";", username);
            stmt.executeUpdate(grantSchemaSql);
            
            // Предоставление прав на таблицы
            String grantTablesSql = String.format("GRANT ALL ON ALL TABLES IN SCHEMA software_app TO \"%s\";", username);
            stmt.executeUpdate(grantTablesSql);
            
            // Предоставление прав на последовательности
            String grantSequencesSql = String.format("GRANT ALL ON ALL SEQUENCES IN SCHEMA software_app TO \"%s\";", username);
            stmt.executeUpdate(grantSequencesSql);

            // Предоставление прав на функции
            String grantFuncs = String.format("GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA software_app TO \"%s\";", username);
            stmt.executeUpdate(grantFuncs);

            // Предоставление прав на процедуры
            String grantProcs = String.format("GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA software_app TO \"%s\";", username);
            stmt.executeUpdate(grantProcs);
        }
    }

    public void closeConnection() {
        if (connection != null) {
            try {
                if (!connection.isClosed()) {
                    connection.close();
                }
            } catch (SQLException e) {
                // Игнорирование ошибок закрытия
            }
            connection = null;
        }
        // Очистка сохраненных креденшиалов
        this.username = null;
        this.password = null;
    }

    @Override
    public void close() {
        if (connection != null) {
            try {
                connection.close();
            } catch (SQLException e) {
                throw new DatabaseException("Failed to close database connection", e);
            }
        }
    }
}
