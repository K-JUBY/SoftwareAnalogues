package com.coursework.softwareanalogues.service;

import com.coursework.softwareanalogues.dao.CategoryDao;
import com.coursework.softwareanalogues.dao.CollectionDao;
import com.coursework.softwareanalogues.dao.DeveloperDao;
import com.coursework.softwareanalogues.dao.ReviewDao;
import com.coursework.softwareanalogues.dao.SoftwareAnalogDao;
import com.coursework.softwareanalogues.dao.SoftwareDao;
import com.coursework.softwareanalogues.dao.ScreenshotDao;
import com.coursework.softwareanalogues.model.Category;
import com.coursework.softwareanalogues.model.CategoryCount;
import com.coursework.softwareanalogues.model.CollectionItem;
import com.coursework.softwareanalogues.model.Developer;
import com.coursework.softwareanalogues.model.Review;
import com.coursework.softwareanalogues.model.Software;
import com.coursework.softwareanalogues.model.SoftwareAnalog;
import com.coursework.softwareanalogues.model.SoftwareFormData;
import com.coursework.softwareanalogues.model.SoftwareSearchCriteria;
import com.coursework.softwareanalogues.model.UserCollection;
import com.coursework.softwareanalogues.model.Screenshot;

import java.util.List;

/**
 * Сервис для управления каталогом программного обеспечения.
 * Обеспечивает операции поиска, добавления, редактирования, удаления ПО,
 * работы с категориями, разработчиками, скриншотами, аналогами и отзывами.
 */
public final class SoftwareService {
    private final SoftwareDao softwareDao;
    private final CategoryDao categoryDao;
    private final DeveloperDao developerDao;
    private final ReviewDao reviewDao;
    private final SoftwareAnalogDao softwareAnalogDao;
    private final CollectionDao collectionDao;
    private final ScreenshotDao screenshotDao;

    /**
     * Конструктор сервиса управления каталогом ПО.
     *
     * @param softwareDao DAO для программного обеспечения
     * @param categoryDao DAO для категорий
     * @param developerDao DAO для разработчиков
     * @param reviewDao DAO для отзывов
     * @param softwareAnalogDao DAO для аналогов
     * @param collectionDao DAO для подборок
     * @param screenshotDao DAO для скриншотов
     */
    public SoftwareService(
            SoftwareDao softwareDao,
            CategoryDao categoryDao,
            DeveloperDao developerDao,
            ReviewDao reviewDao,
            SoftwareAnalogDao softwareAnalogDao,
            CollectionDao collectionDao,
            ScreenshotDao screenshotDao
    ) {
        this.softwareDao = softwareDao;
        this.categoryDao = categoryDao;
        this.developerDao = developerDao;
        this.reviewDao = reviewDao;
        this.softwareAnalogDao = softwareAnalogDao;
        this.collectionDao = collectionDao;
        this.screenshotDao = screenshotDao;
    }

    // Поиск ПО по заданным критериям
    public List<Software> search(SoftwareSearchCriteria criteria) {
        return softwareDao.search(criteria == null ? SoftwareSearchCriteria.empty() : criteria);
    }

    // Загрузка всех категорий ПО
    public List<Category> findCategories() {
        return categoryDao.findAll();
    }

    // Получение статистики по категориям
    public List<CategoryCount> getCategoryCounts() {
        return categoryDao.getCategoryCounts();
    }

    // Загрузка всех разработчиков ПО
    public List<Developer> findDevelopers() {
        return developerDao.findAll();
    }

    // Добавление новой категории ПО
    public Category addCategory(String name, String description) {
        // Валидация обязательного поля name
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("Category name is required");
        }
        return categoryDao.create(name, description);
    }

    // Добавление нового разработчика ПО
    public Developer addDeveloper(String name, String website) {
        // Валидация обязательного поля name
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("Developer name is required");
        }
        // Проверка формата URL сайта
        if (website != null && !website.isBlank() && !website.matches("(?i)^https?://.+")) {
            throw new IllegalArgumentException("Website must start with http:// or https://");
        }
        return developerDao.create(name, website);
    }

    // Создание нового ПО
    public long create(SoftwareFormData data) {
        // Валидация данных формы
        validate(data);
        return softwareDao.create(data);
    }

    // Обновление существующего ПО
    public void update(SoftwareFormData data) {
        // Проверка наличия ID для обновления
        if (data.softwareId() == null) {
            throw new IllegalArgumentException("Software id is required");
        }
        validate(data);
        softwareDao.update(data);
    }

    // Удаление ПО по ID
    public void deleteById(long softwareId) {
        softwareDao.deleteById(softwareId);
    }

    // Загрузка отзывов для конкретного ПО
    public List<Review> findReviews(long softwareId) {
        return reviewDao.findBySoftwareId(softwareId);
    }

    // Добавление нового отзыва
    public long addReview(long softwareId, String text, int rating) {
        // Валидация текста отзыва
        if (text == null || text.isBlank()) {
            throw new IllegalArgumentException("Review text is required");
        }
        // Проверка диапазона оценки
        if (rating < 1 || rating > 5) {
            throw new IllegalArgumentException("Rating must be between 1 and 5");
        }
        return reviewDao.create(softwareId, text, rating);
    }

    // Загрузка аналогов для конкретного ПО
    public List<SoftwareAnalog> findAnalogs(long softwareId) {
        return softwareAnalogDao.findBySoftwareId(softwareId);
    }

    // Добавление аналога к ПО
    public void addAnalog(long softwareId, long analogId, String reason, Short similarityScore) {
        // Проверка на попытку добавить ПО в качестве аналога самому себе
        if (softwareId == analogId) {
            throw new IllegalArgumentException("Software cannot be an analogue of itself");
        }
        // Проверка диапазона оценки схожести
        if (similarityScore != null && (similarityScore < 0 || similarityScore > 100)) {
            throw new IllegalArgumentException("Similarity score must be between 0 and 100");
        }
        softwareAnalogDao.add(softwareId, analogId, reason, similarityScore);
    }

    // Удаление аналога из списка
    public void removeAnalog(long softwareId, long analogId) {
        softwareAnalogDao.remove(softwareId, analogId);
    }

    // Загрузка коллекций текущего пользователя
    public List<UserCollection> findCollections() {
        return collectionDao.findCurrentUserCollections();
    }

    // Создание новой коллекции
    public long createCollection(String title, String description) {
        // Валидация названия коллекции
        if (title == null || title.isBlank()) {
            throw new IllegalArgumentException("Collection title is required");
        }
        return collectionDao.create(title, description);
    }

    // Удаление коллекции по ID
    public void deleteCollection(long collectionId) {
        collectionDao.deleteById(collectionId);
    }

    // Загрузка элементов коллекции
    public List<CollectionItem> findCollectionItems(long collectionId) {
        return collectionDao.findItems(collectionId);
    }

    // Добавление ПО в коллекцию
    public long addCollectionItem(long collectionId, long softwareId, String note, Integer position) {
        // Проверка положительности позиции
        if (position != null && position < 1) {
            throw new IllegalArgumentException("Position must be positive");
        }
        return collectionDao.addItem(collectionId, softwareId, note, position);
    }

    // Удаление ПО из коллекции
    public void removeCollectionItem(long collectionId, long softwareId) {
        collectionDao.removeItem(collectionId, softwareId);
    }

    // Валидация данных формы ПО
    private void validate(SoftwareFormData data) {
        // Проверка обязательного поля title
        if (data.title() == null || data.title().isBlank()) {
            throw new IllegalArgumentException("Software title is required");
        }
        // Проверка неотрицательности размера файла
        if (data.sizeMb() != null && data.sizeMb().signum() < 0) {
            throw new IllegalArgumentException("Software size must not be negative");
        }
        // Проверка соответствия размера типу NUMERIC(10,2)
        if (data.sizeMb() != null && (data.sizeMb().precision() > 10 || data.sizeMb().scale() > 2)) {
            throw new IllegalArgumentException("Software size must fit NUMERIC(10,2)");
        }
        // Проверка формата URL сайта
        if (data.website() != null && !data.website().isBlank() && !data.website().matches("(?i)^https?://.+")) {
            throw new IllegalArgumentException("Website must start with http:// or https://");
        }
    }

    // Загрузка скриншотов для конкретного ПО
    public List<Screenshot> findScreenshots(long softwareId) {
        return screenshotDao.findBySoftwareId(softwareId);
    }

    // Добавление скриншота к ПО
    public long addScreenshot(long softwareId, byte[] imageData, String mimeType, String caption) {
        // Валидация наличия данных изображения
        if (imageData == null || imageData.length == 0) {
            throw new IllegalArgumentException("Screenshot image data is required");
        }
        return screenshotDao.create(softwareId, imageData, mimeType, caption);
    }

    // Удаление скриншота по ID
    public void deleteScreenshot(long screenshotId) {
        screenshotDao.delete(screenshotId);
    }
}
