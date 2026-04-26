package com.coursework.softwareanalogues.service;

import com.coursework.softwareanalogues.config.ConnectionFactory;
import com.coursework.softwareanalogues.dao.UserDao;
import com.coursework.softwareanalogues.exception.AuthenticationException;
import com.coursework.softwareanalogues.model.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.SQLException;

/**
 * Сервис аутентификации пользователей.
 * Управляет сессией текущего пользователя и динамическим подключением к СУБД.
 */
public final class AuthService {
    private static final Logger logger = LoggerFactory.getLogger(AuthService.class);

    private final UserDao userDao;
    private final ConnectionFactory connectionFactory;
    private User currentUser;

    /**
     * Конструктор сервиса аутентификации.
     *
     * @param userDao объект доступа к данным пользователей
     * @param connectionFactory фабрика соединений с СУБД
     */
    public AuthService(UserDao userDao, ConnectionFactory connectionFactory) {
        this.userDao = userDao;
        this.connectionFactory = connectionFactory;
    }

    /**
     * Аутентифицирует пользователя в приложении и устанавливает соединение с СУБД.
     *
     * @param username имя пользователя
     * @param password пароль
     * @return объект аутентифицированного пользователя
     * @throws AuthenticationException в случае неверных учетных данных или ошибки подключения
     */
    public User login(String username, String password) {
        // Проверка обязательных полей
        if (username == null || username.isBlank() || password == null || password.isBlank()) {
            throw new AuthenticationException("Username and password are required");
        }

        // Установка соединения с БД
        try {
            connectionFactory.initConnection(username.trim(), password);
        } catch (SQLException e) {
            throw new AuthenticationException("Database connection failed: " + e.getMessage(), e);
        }

        // Вызов функции authenticate_user() в PostgreSQL
        User authenticatedUser = userDao.authenticate(username.trim(), password)
                .orElseThrow(() -> new AuthenticationException("Invalid user profile"));
        
        // Установка текущего пользователя в сессии БД
        connectionFactory.setCurrentAppUser(authenticatedUser.userId());
        currentUser = authenticatedUser;
        logger.info("User '{}' authenticated via DBMS", authenticatedUser.username());
        return authenticatedUser;
    }

    /**
     * Регистрирует нового пользователя в СУБД и создает соответствующую роль в PostgreSQL.
     *
     * @param username имя нового пользователя
     * @param password пароль
     */
    public void register(String username, String password) {
        // Валидация обязательных полей
        if (username == null || username.isBlank() || password == null || password.isBlank()) {
            throw new IllegalArgumentException("Username and password are required");
        }
        // Проверка формата логина
        if (!username.trim().matches("^[a-zA-Z0-9_]{3,30}$")) {
            throw new IllegalArgumentException("invalid.username.format");
        }
        // Проверка минимальной длины пароля
        if (password.length() < 6) {
            throw new IllegalArgumentException("invalid.password.length");
        }
        // Создание роли в PostgreSQL и вызов create_app_user()
        try {
            connectionFactory.registerUser(username.trim(), password);
            logger.info("New DBMS user '{}' registered successfully", username.trim());
        } catch (SQLException e) {
            logger.error("Failed to register user '{}' via DBMS", username, e);
            throw new com.coursework.softwareanalogues.exception.DatabaseException("Registration failed", e);
        }
    }

    /**
     * Возвращает текущего авторизованного пользователя.
     *
     * @return текущий пользователь или null, если пользователь не авторизован
     */
    public User currentUser() {
        return currentUser;
    }

    /**
     * Выходит из системы, очищает текущую сессию пользователя и закрывает соединение.
     */
    public void logout() {
        // Очистка сессии и закрытие соединения
        currentUser = null;
        connectionFactory.closeConnection();
    }
}
