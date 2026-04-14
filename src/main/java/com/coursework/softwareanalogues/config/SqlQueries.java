package com.coursework.softwareanalogues.config;

import com.coursework.softwareanalogues.exception.AppException;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public final class SqlQueries {
    private final Properties properties;

    private SqlQueries(Properties properties) {
        this.properties = properties;
    }

    public static SqlQueries load() {
        Properties properties = new Properties();
        // Загрузка SQL запросов из resources/db/sql.properties
        try (InputStream input = SqlQueries.class.getResourceAsStream("/db/sql.properties")) {
            if (input == null) {
                throw new AppException("db/sql.properties not found");
            }
            properties.load(input);
        } catch (IOException e) {
            throw new AppException("Failed to load SQL properties", e);
        }
        return new SqlQueries(properties);
    }

    public String get(String key) {
        // Получение SQL запроса по ключу
        String sql = properties.getProperty(key);
        if (sql == null || sql.isBlank()) {
            throw new AppException("SQL query not found: " + key);
        }
        return sql;
    }
}
