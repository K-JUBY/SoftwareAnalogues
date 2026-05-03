package com.coursework.softwareanalogues.controller;

import com.coursework.softwareanalogues.config.AppContext;
import com.coursework.softwareanalogues.model.Review;
import com.coursework.softwareanalogues.model.Software;
import com.coursework.softwareanalogues.model.SoftwareAnalog;
import com.coursework.softwareanalogues.model.SoftwareSearchCriteria;
import com.coursework.softwareanalogues.model.UserCollection;
import com.coursework.softwareanalogues.util.DialogUtils;
import com.coursework.softwareanalogues.util.TranslationUtils;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Label;
import javafx.scene.control.Spinner;
import javafx.scene.control.SpinnerValueFactory;
import javafx.scene.control.TableColumn;
import javafx.scene.control.TableView;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;
import javafx.scene.control.Button;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import javafx.scene.layout.HBox;
import javafx.util.StringConverter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.coursework.softwareanalogues.model.Screenshot;

import java.io.ByteArrayInputStream;
import java.util.ArrayList;
import java.util.List;

public final class SoftwareDetailsController {
    private static final Logger logger = LoggerFactory.getLogger(SoftwareDetailsController.class);

    private final AppContext appContext;
    private final Software software;
    private final Runnable onChanged;

    @FXML
    private TextField titleField;
    @FXML
    private TextField categoryField;
    @FXML
    private TextField developerField;
    @FXML
    private TextField licenseField;
    @FXML
    private TextField websiteField;
    @FXML
    private TextArea descriptionArea;
    @FXML
    private TextArea requirementsArea;
    @FXML
    private TableView<Review> reviewsTable;
    @FXML
    private TableColumn<Review, String> reviewAuthorColumn;
    @FXML
    private TableColumn<Review, String> reviewRatingColumn;
    @FXML
    private TableColumn<Review, String> reviewTextColumn;
    @FXML
    private TextArea reviewTextArea;
    @FXML
    private Spinner<Integer> ratingSpinner;
    @FXML
    private TableView<SoftwareAnalog> analogsTable;
    @FXML
    private TableColumn<SoftwareAnalog, String> analogTitleColumn;
    @FXML
    private TableColumn<SoftwareAnalog, String> analogReasonColumn;
    @FXML
    private TableColumn<SoftwareAnalog, String> analogScoreColumn;
    @FXML
    private ComboBox<Software> analogComboBox;
    @FXML
    private TextField analogReasonField;
    @FXML
    private Spinner<Integer> analogScoreSpinner;
    @FXML
    private ComboBox<UserCollection> collectionComboBox;
    @FXML
    private TextField collectionNoteField;
    @FXML
    private ImageView screenshotImageView;
    @FXML
    private Label noScreenshotLabel;
    @FXML
    private HBox screenshotPaginationBox;
    @FXML
    private Button prevScreenshotButton;
    @FXML
    private Button nextScreenshotButton;
    @FXML
    private Label screenshotIndexLabel;
    @FXML
    private Button deleteScreenshotButton;

    private List<Screenshot> screenshotsList = new ArrayList<>();
    private int currentScreenshotIndex = 0;

    public SoftwareDetailsController(AppContext appContext, Software software, Runnable onChanged) {
        this.appContext = appContext;
        this.software = software;
        this.onChanged = onChanged;
    }

    @FXML
    private void initialize() {
        fillSoftwareFields();
        configureTables();
        // Настройка спиннеров для рейтинга и схожести
        ratingSpinner.setValueFactory(new SpinnerValueFactory.IntegerSpinnerValueFactory(1, 5, 5));
        analogScoreSpinner.setValueFactory(new SpinnerValueFactory.IntegerSpinnerValueFactory(0, 100, 80));
        configureComboBoxes();
        loadReviews();
        loadAnalogs();
        loadAnalogChoices();
        loadCollections();
        loadScreenshots();
    }

    @FXML
    private void onAddReview() {
        try {
            // Создание отзыва с текстом и рейтингом
            appContext.softwareService().addReview(software.softwareId(), reviewTextArea.getText(), ratingSpinner.getValue());
            reviewTextArea.clear();
            loadReviews();
            onChanged.run();
        } catch (RuntimeException e) {
            logger.warn("Review creation failed", e);
            DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("review.add.error"));
        }
    }

    @FXML
    private void onAddAnalog() {
        Software selected = analogComboBox.getValue();
        if (selected == null) {
            DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("analog.select.required"));
            return;
        }
        try {
            // Связывание программ как аналогов с указанием схожести
            appContext.softwareService().addAnalog(
                    software.softwareId(),
                    selected.softwareId(),
                    analogReasonField.getText(),
                    analogScoreSpinner.getValue().shortValue()
            );
            analogReasonField.clear();
            loadAnalogs();
        } catch (RuntimeException e) {
            logger.warn("Analogue creation failed", e);
            DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("analog.add.error"));
        }
    }

    @FXML
    private void onRemoveAnalog() {
        SoftwareAnalog selected = analogsTable.getSelectionModel().getSelectedItem();
        if (selected == null) {
            DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("analog.select.required"));
            return;
        }
        // Удаление связи между аналогами
        appContext.softwareService().removeAnalog(software.softwareId(), selected.analogId());
        loadAnalogs();
    }

    @FXML
    private void onAddToCollection() {
        UserCollection selected = collectionComboBox.getValue();
        if (selected == null) {
            DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("collection.select.required"));
            return;
        }
        try {
            // Добавление программы в выбранную коллекцию с заметкой
            appContext.softwareService().addCollectionItem(selected.collectionId(), software.softwareId(), collectionNoteField.getText(), null);
            collectionNoteField.clear();
        } catch (RuntimeException e) {
            logger.warn("Adding to collection failed", e);
            DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("collection.item.add.error"));
        }
    }

    private void fillSoftwareFields() {
        titleField.setText(software.title());
        categoryField.setText(TranslationUtils.getLocalizedCategory(software.categoryName(), appContext.messages()));
        developerField.setText(software.developerName());
        licenseField.setText(software.free() ? appContext.messages().getString("license.free") : appContext.messages().getString("license.paid"));
        websiteField.setText(software.website());
        descriptionArea.setText(software.description());
        requirementsArea.setText(software.systemRequirements());
    }

    private void configureTables() {
        reviewAuthorColumn.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().authorName()));
        reviewRatingColumn.setCellValueFactory(data -> new SimpleStringProperty(Integer.toString(data.getValue().rating())));
        reviewTextColumn.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().reviewText()));
        analogTitleColumn.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().analogTitle()));
        analogReasonColumn.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().reason()));
        analogScoreColumn.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().similarityScore() == null ? "" : data.getValue().similarityScore().toString()));
    }

    private void configureComboBoxes() {
        analogComboBox.setConverter(new StringConverter<>() {
            @Override
            public String toString(Software item) {
                return item == null ? "" : item.title();
            }

            @Override
            public Software fromString(String string) {
                return null;
            }
        });
        collectionComboBox.setConverter(new StringConverter<>() {
            @Override
            public String toString(UserCollection collection) {
                return collection == null ? "" : collection.title();
            }

            @Override
            public UserCollection fromString(String string) {
                return null;
            }
        });
    }

    private void loadReviews() {
        reviewsTable.setItems(FXCollections.observableArrayList(appContext.softwareService().findReviews(software.softwareId())));
    }

    private void loadAnalogs() {
        analogsTable.setItems(FXCollections.observableArrayList(appContext.softwareService().findAnalogs(software.softwareId())));
    }

    private void loadAnalogChoices() {
        var items = appContext.softwareService().search(SoftwareSearchCriteria.empty()).stream()
                .filter(item -> item.softwareId() != software.softwareId())
                .toList();
        analogComboBox.setItems(FXCollections.observableArrayList(items));
    }

    private void loadCollections() {
        collectionComboBox.setItems(FXCollections.observableArrayList(appContext.softwareService().findCollections()));
    }

    private void loadScreenshots() {
        try {
            screenshotsList = appContext.softwareService().findScreenshots(software.softwareId());
            if (!screenshotsList.isEmpty()) {
                // Коррекция индекса при выходе за границы
                if (currentScreenshotIndex < 0 || currentScreenshotIndex >= screenshotsList.size()) {
                    currentScreenshotIndex = 0;
                }
                showScreenshot(currentScreenshotIndex);
                
                // Отображение элементов управления скриншотами
                screenshotPaginationBox.setVisible(true);
                screenshotPaginationBox.setManaged(true);
                noScreenshotLabel.setVisible(false);
                noScreenshotLabel.setManaged(false);
                deleteScreenshotButton.setVisible(true);
                deleteScreenshotButton.setManaged(true);
                
                // Кнопки пролистывания только при нескольких скриншотах
                boolean canPage = screenshotsList.size() > 1;
                prevScreenshotButton.setVisible(canPage);
                prevScreenshotButton.setManaged(canPage);
                nextScreenshotButton.setVisible(canPage);
                nextScreenshotButton.setManaged(canPage);
            } else {
                // Скрытие элементов при отсутствии скриншотов
                screenshotImageView.setImage(null);
                screenshotPaginationBox.setVisible(false);
                screenshotPaginationBox.setManaged(false);
                noScreenshotLabel.setVisible(true);
                noScreenshotLabel.setManaged(true);
                deleteScreenshotButton.setVisible(false);
                deleteScreenshotButton.setManaged(false);
            }
        } catch (Exception e) {
            logger.error("Failed to load screenshots", e);
            screenshotImageView.setImage(null);
            screenshotPaginationBox.setVisible(false);
            screenshotPaginationBox.setManaged(false);
            noScreenshotLabel.setVisible(true);
            noScreenshotLabel.setManaged(true);
            deleteScreenshotButton.setVisible(false);
            deleteScreenshotButton.setManaged(false);
        }
    }

    private void showScreenshot(int index) {
        if (index >= 0 && index < screenshotsList.size()) {
            var screenshot = screenshotsList.get(index);
            // Преобразование BYTEA в Image через ByteArrayInputStream
            var stream = new ByteArrayInputStream(screenshot.imageData());
            var image = new Image(stream);
            screenshotImageView.setImage(image);
            // Отображение текущего индекса
            screenshotIndexLabel.setText((index + 1) + " / " + screenshotsList.size());
        }
    }

    @FXML
    private void onPrevScreenshot() {
        if (screenshotsList.isEmpty()) return;
        currentScreenshotIndex--;
        // Циклическое перелистывание в начало
        if (currentScreenshotIndex < 0) {
            currentScreenshotIndex = screenshotsList.size() - 1;
        }
        showScreenshot(currentScreenshotIndex);
    }

    @FXML
    private void onNextScreenshot() {
        if (screenshotsList.isEmpty()) return;
        currentScreenshotIndex++;
        // Циклическое перелистывание в конец
        if (currentScreenshotIndex >= screenshotsList.size()) {
            currentScreenshotIndex = 0;
        }
        showScreenshot(currentScreenshotIndex);
    }

    @FXML
    private void onDeleteCurrentScreenshot() {
        if (screenshotsList.isEmpty() || currentScreenshotIndex < 0 || currentScreenshotIndex >= screenshotsList.size()) {
            return;
        }
        
        var messages = appContext.messages();
        boolean confirm = DialogUtils.confirm(
                messages.getString("screenshot.delete.confirm.title"),
                messages.getString("screenshot.delete.confirm.message")
        );
        
        if (confirm) {
            try {
                var screenshot = screenshotsList.get(currentScreenshotIndex);
                appContext.softwareService().deleteScreenshot(screenshot.screenshotId());
                if (currentScreenshotIndex >= screenshotsList.size() - 1) {
                    currentScreenshotIndex = Math.max(0, screenshotsList.size() - 2);
                }
                loadScreenshots();
                onChanged.run();
            } catch (Exception e) {
                logger.error("Failed to delete screenshot", e);
                DialogUtils.showError(messages.getString("error.title"), messages.getString("screenshot.delete.error"));
            }
        }
    }

    @FXML
    private void onAddScreenshotDirect() {
        var fileChooser = new javafx.stage.FileChooser();
        var messages = appContext.messages();
        fileChooser.setTitle(messages.getString("screenshot.select.title"));
        fileChooser.getExtensionFilters().addAll(
                new javafx.stage.FileChooser.ExtensionFilter("Image Files", "*.png", "*.jpg", "*.jpeg", "*.webp")
        );
        var file = fileChooser.showOpenDialog(screenshotImageView.getScene().getWindow());
        if (file != null) {
            try {
                // Чтение файла в память
                byte[] bytes = java.nio.file.Files.readAllBytes(file.toPath());
                String name = file.getName().toLowerCase();
                // Определение MIME-типа по расширению
                String mimeType;
                if (name.endsWith(".png")) mimeType = "image/png";
                else if (name.endsWith(".webp")) mimeType = "image/webp";
                else mimeType = "image/jpeg";
                
                // Сохранение в БД как BYTEA
                appContext.softwareService().addScreenshot(software.softwareId(), bytes, mimeType, "Screenshot " + (screenshotsList.size() + 1));
                
                // Автопереход на новый скриншот
                currentScreenshotIndex = screenshotsList.size();
                loadScreenshots();
                onChanged.run();
            } catch (Exception e) {
                logger.error("Failed to add screenshot", e);
                DialogUtils.showError(messages.getString("error.title"), messages.getString("screenshot.add.error"));
            }
        }
    }
}
