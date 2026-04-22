package com.coursework.softwareanalogues.dao.jdbc;

import com.coursework.softwareanalogues.config.ConnectionFactory;
import com.coursework.softwareanalogues.config.SqlQueries;
import com.coursework.softwareanalogues.dao.ReviewDao;
import com.coursework.softwareanalogues.exception.DatabaseException;
import com.coursework.softwareanalogues.model.Review;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public final class JdbcReviewDao implements ReviewDao {
    private final ConnectionFactory connectionFactory;
    private final SqlQueries sqlQueries;

    public JdbcReviewDao(ConnectionFactory connectionFactory, SqlQueries sqlQueries) {
        this.connectionFactory = connectionFactory;
        this.sqlQueries = sqlQueries;
    }

    @Override
    public List<Review> findBySoftwareId(long softwareId) {
        // Загрузка отзывов для конкретного ПО
        List<Review> reviews = new ArrayList<>();
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("review.findBySoftware"))) {
            statement.setLong(1, softwareId);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    reviews.add(mapReview(resultSet));
                }
            }
            return reviews;
        } catch (SQLException e) {
            throw new DatabaseException("Failed to load reviews", e);
        }
    }

    @Override
    public long create(long softwareId, String text, int rating) {
        // Создание нового отзыва в БД
        try (var statement = connectionFactory.getConnection().prepareStatement(sqlQueries.get("review.create"))) {
            statement.setLong(1, softwareId);
            statement.setString(2, text);
            statement.setShort(3, (short) rating);
            try (ResultSet resultSet = statement.executeQuery()) {
                resultSet.next();
                // Возврат ID созданного отзыва
                return resultSet.getLong(1);
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to create review", e);
        }
    }

    // Маппинг ResultSet в объект Review
    private Review mapReview(ResultSet resultSet) throws SQLException {
        long userId = resultSet.getLong("user_id");
        // Обработка nullable поля user_id
        return new Review(
                resultSet.getLong("review_id"),
                resultSet.getLong("software_id"),
                resultSet.wasNull() ? null : userId,
                resultSet.getString("author_name"),
                resultSet.getString("review_text"),
                resultSet.getInt("rating"),
                resultSet.getObject("created_at", java.time.OffsetDateTime.class),
                resultSet.getObject("updated_at", java.time.OffsetDateTime.class)
        );
    }
}
