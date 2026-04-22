package com.coursework.softwareanalogues.dao.jdbc;

import com.coursework.softwareanalogues.config.ConnectionFactory;
import com.coursework.softwareanalogues.dao.ScreenshotDao;
import com.coursework.softwareanalogues.exception.DatabaseException;
import com.coursework.softwareanalogues.model.Screenshot;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public final class JdbcScreenshotDao implements ScreenshotDao {
    private final ConnectionFactory connectionFactory;

    public JdbcScreenshotDao(ConnectionFactory connectionFactory) {
        this.connectionFactory = connectionFactory;
    }

    @Override
    public List<Screenshot> findBySoftwareId(long softwareId) {
        // Загрузка скриншотов ПО из БД
        String sql = "SELECT screenshot_id, software_id, image_data, mime_type, caption " +
                     "FROM software_app.screenshots WHERE software_id = ? ORDER BY created_at;";
        List<Screenshot> list = new ArrayList<>();
        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            statement.setLong(1, softwareId);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    // Маппинг результата в объект Screenshot
                    list.add(new Screenshot(
                            resultSet.getLong("screenshot_id"),
                            resultSet.getLong("software_id"),
                            resultSet.getBytes("image_data"),
                            resultSet.getString("mime_type"),
                            resultSet.getString("caption")
                    ));
                }
            }
            return list;
        } catch (SQLException e) {
            throw new DatabaseException("Failed to fetch screenshots", e);
        }
    }

    @Override
    public long create(long softwareId, byte[] imageData, String mimeType, String caption) {
        // Сохранение скриншота в БД
        String sql = "INSERT INTO software_app.screenshots (software_id, image_data, mime_type, caption) " +
                     "VALUES (?, ?, ?, ?) RETURNING screenshot_id;";
        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            statement.setLong(1, softwareId);
            statement.setBytes(2, imageData);
            statement.setString(3, mimeType);
            statement.setString(4, caption);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    // Возврат ID созданного скриншота
                    return resultSet.getLong("screenshot_id");
                }
                throw new DatabaseException("Failed to obtain generated screenshot id");
            }
        } catch (SQLException e) {
            throw new DatabaseException("Failed to save screenshot", e);
        }
    }

    @Override
    public void delete(long screenshotId) {
        // Удаление скриншота из БД
        String sql = "DELETE FROM software_app.screenshots WHERE screenshot_id = ?;";
        try (var statement = connectionFactory.getConnection().prepareStatement(sql)) {
            statement.setLong(1, screenshotId);
            statement.executeUpdate();
        } catch (SQLException e) {
            throw new DatabaseException("Failed to delete screenshot", e);
        }
    }
}
