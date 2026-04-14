package com.coursework.softwareanalogues.config;

import com.coursework.softwareanalogues.dao.CategoryDao;
import com.coursework.softwareanalogues.dao.CollectionDao;
import com.coursework.softwareanalogues.dao.DeveloperDao;
import com.coursework.softwareanalogues.dao.ReviewDao;
import com.coursework.softwareanalogues.dao.SoftwareAnalogDao;
import com.coursework.softwareanalogues.dao.SoftwareDao;
import com.coursework.softwareanalogues.dao.UserDao;
import com.coursework.softwareanalogues.dao.ScreenshotDao;
import com.coursework.softwareanalogues.dao.jdbc.JdbcCategoryDao;
import com.coursework.softwareanalogues.dao.jdbc.JdbcCollectionDao;
import com.coursework.softwareanalogues.dao.jdbc.JdbcDeveloperDao;
import com.coursework.softwareanalogues.dao.jdbc.JdbcReviewDao;
import com.coursework.softwareanalogues.dao.jdbc.JdbcSoftwareAnalogDao;
import com.coursework.softwareanalogues.dao.jdbc.JdbcSoftwareDao;
import com.coursework.softwareanalogues.dao.jdbc.JdbcUserDao;
import com.coursework.softwareanalogues.dao.jdbc.JdbcScreenshotDao;
import com.coursework.softwareanalogues.service.AuthService;
import com.coursework.softwareanalogues.service.SoftwareService;

import java.util.Locale;
import java.util.ResourceBundle;

public final class AppContext implements AutoCloseable {
    private final DatabaseConfig databaseConfig;
    private final ConnectionFactory connectionFactory;
    private ResourceBundle messages;
    private final SqlQueries sqlQueries;
    private final UserDao userDao;
    private final CategoryDao categoryDao;
    private final DeveloperDao developerDao;
    private final SoftwareDao softwareDao;
    private final ReviewDao reviewDao;
    private final SoftwareAnalogDao softwareAnalogDao;
    private final CollectionDao collectionDao;
    private final ScreenshotDao screenshotDao;
    private final AuthService authService;
    private final SoftwareService softwareService;

    // Инициализация всех компонентов приложения
    private AppContext(DatabaseConfig databaseConfig, ResourceBundle messages) {
        this.databaseConfig = databaseConfig;
        this.messages = messages;
        // Загрузка SQL запросов из конфигурации
        this.sqlQueries = SqlQueries.load();
        // Создание фабрики подключений к БД
        this.connectionFactory = new ConnectionFactory(databaseConfig, sqlQueries);
        // Инициализация DAO слоя
        this.userDao = new JdbcUserDao(connectionFactory, sqlQueries);
        this.categoryDao = new JdbcCategoryDao(connectionFactory, sqlQueries);
        this.developerDao = new JdbcDeveloperDao(connectionFactory, sqlQueries);
        this.softwareDao = new JdbcSoftwareDao(connectionFactory, sqlQueries);
        this.reviewDao = new JdbcReviewDao(connectionFactory, sqlQueries);
        this.softwareAnalogDao = new JdbcSoftwareAnalogDao(connectionFactory, sqlQueries);
        this.collectionDao = new JdbcCollectionDao(connectionFactory, sqlQueries);
        this.screenshotDao = new JdbcScreenshotDao(connectionFactory);
        // Инициализация сервисов
        this.authService = new AuthService(userDao, connectionFactory);
        this.softwareService = new SoftwareService(
                softwareDao,
                categoryDao,
                developerDao,
                reviewDao,
                softwareAnalogDao,
                collectionDao,
                screenshotDao
        );
    }

    // Создание экземпляра контекста приложения
    public static AppContext create() {
        DatabaseConfig databaseConfig = DatabaseConfig.load();
        
        // Проверка переопределения локали через системное свойство
        String localeOverride = System.getProperty("app.locale.override");
        String localeString = localeOverride != null ? localeOverride : databaseConfig.locale();
        
        // Установка локали по умолчанию и загрузка сообщений
        Locale locale = Locale.forLanguageTag(localeString);
        Locale.setDefault(locale);
        ResourceBundle messages = ResourceBundle.getBundle("i18n.messages", locale);
        return new AppContext(databaseConfig, messages);
    }

    // Смена языка интерфейса во время выполнения
    public void setLocale(Locale locale) {
        Locale.setDefault(locale);
        this.messages = ResourceBundle.getBundle("i18n.messages", locale);
    }

    // Получение текущего бандла локализации
    public ResourceBundle messages() {
        return messages;
    }

    // Получение сервиса аутентификации
    public AuthService authService() {
        return authService;
    }

    // Получение сервиса управления ПО
    public SoftwareService softwareService() {
        return softwareService;
    }

    // Получение DAO для работы со скриншотами
    public ScreenshotDao screenshotDao() {
        return screenshotDao;
    }

    // Закрытие ресурсов при завершении работы
    @Override
    public void close() {
        connectionFactory.close();
    }
}
