package com.coursework.softwareanalogues.controller;

import com.coursework.softwareanalogues.config.AppContext;
import com.coursework.softwareanalogues.model.Category;
import com.coursework.softwareanalogues.model.Developer;
import com.coursework.softwareanalogues.model.Software;
import com.coursework.softwareanalogues.model.SoftwareFormData;
import com.coursework.softwareanalogues.model.SoftwareFormMode;
import com.coursework.softwareanalogues.util.DialogUtils;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.Button;
import javafx.scene.control.CheckBox;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Label;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;
import javafx.stage.Stage;
import javafx.util.StringConverter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

public final class SoftwareFormController {
    private static final Logger logger = LoggerFactory.getLogger(SoftwareFormController.class);

    private final AppContext appContext;
    private final SoftwareFormMode mode;
    private final Software software;
    private final Runnable onSaved;

    @FXML
    private TextField titleField;
    @FXML
    private TextArea descriptionArea;
    @FXML
    private TextArea requirementsArea;
    @FXML
    private TextField sizeField;
    @FXML
    private TextField websiteField;
    @FXML
    private ComboBox<Category> categoryComboBox;
    @FXML
    private ComboBox<Developer> developerComboBox;
    @FXML
    private CheckBox freeCheckBox;
    @FXML
    private Button uploadScreenshotButton;
    @FXML
    private Label screenshotLabel;

    private final List<byte[]> uploadedScreenshotsBytes = new ArrayList<>();
    private final List<String> uploadedScreenshotsMimeTypes = new ArrayList<>();

    public SoftwareFormController(AppContext appContext, SoftwareFormMode mode, Software software, Runnable onSaved) {
        this.appContext = appContext;
        this.mode = mode;
        this.software = software;
        this.onSaved = onSaved;
    }

    @FXML
    private void initialize() {
        configureComboBoxes();
        // Загрузка справочников категорий и разработчиков
        categoryComboBox.setItems(FXCollections.observableArrayList(appContext.softwareService().findCategories()));
        developerComboBox.setItems(FXCollections.observableArrayList(appContext.softwareService().findDevelopers()));
        // Заполнение формы при редактировании
        if (mode == SoftwareFormMode.EDIT && software != null) {
            fillForm();
            checkExistingScreenshots();
        }
    }

    private void checkExistingScreenshots() {
        try {
            var list = appContext.softwareService().findScreenshots(software.softwareId());
            if (!list.isEmpty()) {
                screenshotLabel.setText(appContext.messages().getString("screenshot.exists"));
            }
        } catch (Exception e) {
            logger.error("Failed to check existing screenshots", e);
        }
    }

    @FXML
    private void onSave() {
        try {
            SoftwareFormData data = collectFormData();
            long softwareId;
            // Создание или обновление записи
            if (mode == SoftwareFormMode.CREATE) {
                softwareId = appContext.softwareService().create(data);
            } else {
                appContext.softwareService().update(data);
                softwareId = software.softwareId();
            }

            // Загрузка выбранных скриншотов
            for (int i = 0; i < uploadedScreenshotsBytes.size(); i++) {
                appContext.softwareService().addScreenshot(softwareId, uploadedScreenshotsBytes.get(i), uploadedScreenshotsMimeTypes.get(i), "Screenshot " + (i + 1));
            }

            onSaved.run();
        } catch (RuntimeException e) {
            logger.warn("Software form save failed", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("software.form.error")
            );
        }
    }

    @FXML
    private void onUploadScreenshot() {
        var fileChooser = new javafx.stage.FileChooser();
        fileChooser.setTitle(appContext.messages().getString("screenshot.select.title"));
        fileChooser.getExtensionFilters().addAll(
                new javafx.stage.FileChooser.ExtensionFilter("Image Files", "*.png", "*.jpg", "*.jpeg", "*.webp")
        );
        var files = fileChooser.showOpenMultipleDialog(titleField.getScene().getWindow());
        if (files != null && !files.isEmpty()) {
            uploadedScreenshotsBytes.clear();
            uploadedScreenshotsMimeTypes.clear();
            // Чтение выбранных файлов в память
            for (var file : files) {
                try {
                    byte[] bytes = java.nio.file.Files.readAllBytes(file.toPath());
                    String name = file.getName().toLowerCase();
                    // Определение MIME-типа по расширению
                    String mimeType;
                    if (name.endsWith(".png")) mimeType = "image/png";
                    else if (name.endsWith(".webp")) mimeType = "image/webp";
                    else mimeType = "image/jpeg";
                    uploadedScreenshotsBytes.add(bytes);
                    uploadedScreenshotsMimeTypes.add(mimeType);
                } catch (java.io.IOException e) {
                    logger.error("Failed to read screenshot file", e);
                    DialogUtils.showError(
                            appContext.messages().getString("error.title"),
                            appContext.messages().getString("error.read_image") + ": " + file.getName()
                    );
                }
            }
            screenshotLabel.setText(appContext.messages().getString("screenshot.selected.count") + ": " + uploadedScreenshotsBytes.size());
        }
    }

    @FXML
    private void onCancel() {
        Stage stage = (Stage) titleField.getScene().getWindow();
        stage.close();
    }

    @FXML
    private void onAddCategory() {
        var dialog = new javafx.scene.control.TextInputDialog();
        dialog.setTitle(appContext.messages().getString("category.add.title"));
        dialog.setHeaderText(appContext.messages().getString("category.add.header"));
        dialog.setContentText(appContext.messages().getString("category.add.label"));
        
        var result = dialog.showAndWait();
        result.ifPresent(name -> {
            if (!name.isBlank()) {
                try {
                    // Создание новой категории через сервис
                    Category newCategory = appContext.softwareService().addCategory(name.trim(), "");
                    categoryComboBox.setItems(FXCollections.observableArrayList(appContext.softwareService().findCategories()));
                    // Автовыбор только что созданной категории
                    categoryComboBox.getItems().stream()
                            .filter(c -> c.categoryId() == newCategory.categoryId())
                            .findFirst()
                            .ifPresent(categoryComboBox::setValue);
                } catch (Exception e) {
                    logger.error("Failed to add category", e);
                    DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("category.add.error"));
                }
            }
        });
    }

    @FXML
    private void onAddDeveloper() {
        var dialog = new javafx.scene.control.TextInputDialog();
        dialog.setTitle(appContext.messages().getString("developer.add.title"));
        dialog.setHeaderText(appContext.messages().getString("developer.add.header"));
        dialog.setContentText(appContext.messages().getString("developer.add.label"));
        
        var result = dialog.showAndWait();
        result.ifPresent(name -> {
            if (!name.isBlank()) {
                try {
                    // Создание нового разработчика через сервис
                    Developer newDeveloper = appContext.softwareService().addDeveloper(name.trim(), "");
                    developerComboBox.setItems(FXCollections.observableArrayList(appContext.softwareService().findDevelopers()));
                    // Автовыбор только что созданного разработчика
                    developerComboBox.getItems().stream()
                            .filter(d -> d.developerId() == newDeveloper.developerId())
                            .findFirst()
                            .ifPresent(developerComboBox::setValue);
                } catch (Exception e) {
                    logger.error("Failed to add developer", e);
                    DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("developer.add.error"));
                }
            }
        });
    }

    private void configureComboBoxes() {
        categoryComboBox.setConverter(new StringConverter<>() {
            @Override
            public String toString(Category category) {
                return category == null ? "" : category.name();
            }

            @Override
            public Category fromString(String string) {
                return null;
            }
        });
        developerComboBox.setConverter(new StringConverter<>() {
            @Override
            public String toString(Developer developer) {
                return developer == null ? "" : developer.name();
            }

            @Override
            public Developer fromString(String string) {
                return null;
            }
        });
    }

    private void fillForm() {
        titleField.setText(software.title());
        descriptionArea.setText(software.description());
        requirementsArea.setText(software.systemRequirements());
        sizeField.setText(software.sizeMb() == null ? "" : software.sizeMb().toString());
        websiteField.setText(software.website());
        freeCheckBox.setSelected(software.free());
        categoryComboBox.getItems().stream()
                .filter(category -> software.categoryId() != null && category.categoryId() == software.categoryId())
                .findFirst()
                .ifPresent(categoryComboBox::setValue);
        developerComboBox.getItems().stream()
                .filter(developer -> software.developerId() != null && developer.developerId() == software.developerId())
                .findFirst()
                .ifPresent(developerComboBox::setValue);
    }

    private SoftwareFormData collectFormData() {
        Category category = categoryComboBox.getValue();
        Developer developer = developerComboBox.getValue();
        return new SoftwareFormData(
                software == null ? null : software.softwareId(),
                titleField.getText(),
                descriptionArea.getText(),
                requirementsArea.getText(),
                parseSize(),
                websiteField.getText(),
                category == null ? null : category.categoryId(),
                developer == null ? null : developer.developerId(),
                freeCheckBox.isSelected()
        );
    }

    private BigDecimal parseSize() {
        String text = sizeField.getText();
        if (text == null || text.isBlank()) {
            return null;
        }
        try {
            // Замена запятой на точку для парсинга
            return new BigDecimal(text.trim().replace(',', '.'));
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid software size", e);
        }
    }
}
