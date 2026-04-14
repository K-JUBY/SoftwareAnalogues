package com.coursework.softwareanalogues.config;

import com.coursework.softwareanalogues.exception.AppException;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public record DatabaseConfig(String url, String username, String password, String locale) {
    public static DatabaseConfig load() {
        Properties properties = new Properties();
        // Загрузка конфигурации из classpath
        try (InputStream input = DatabaseConfig.class.getResourceAsStream("/application.properties")) {
            if (input == null) {
                throw new AppException("application.properties not found");
            }
            properties.load(input);
        } catch (IOException e) {
            throw new AppException("Failed to load application.properties", e);
        }

        return new DatabaseConfig(
                required(properties, "db.url"),
                required(properties, "db.username"),
                properties.getProperty("db.password", ""),
                properties.getProperty("app.locale", "ru")
        );
    }

    private static String required(Properties properties, String key) {
        String value = properties.getProperty(key);
        if (value == null || value.isBlank()) {
            throw new AppException("Required property is missing: " + key);
        }
        return value;
    }
}
