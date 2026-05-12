package com.coursework.softwareanalogues.controller;

import com.coursework.softwareanalogues.config.AppContext;
import com.coursework.softwareanalogues.model.CategoryCount;
import com.coursework.softwareanalogues.model.Developer;
import com.coursework.softwareanalogues.model.Software;
import com.coursework.softwareanalogues.model.SoftwareSearchCriteria;
import com.coursework.softwareanalogues.util.DialogUtils;
import com.coursework.softwareanalogues.util.TranslationUtils;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;
import javafx.stage.FileChooser;
import javafx.stage.Stage;
import javafx.util.StringConverter;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class ReportsController {
    private final AppContext appContext;

    @FXML
    private ComboBox<String> reportTypeComboBox;
    @FXML
    private Label developerLabel;
    @FXML
    private ComboBox<Developer> developerComboBox;
    @FXML
    private TableView<Object> reportTable;

    private String reportTypeAll;
    private String reportTypeCategories;
    private String reportTypeDevelopers;

    public ReportsController(AppContext appContext) {
        this.appContext = appContext;
    }

    @FXML
    private void initialize() {
        reportTypeAll = appContext.messages().getString("report.type.all");
        reportTypeCategories = appContext.messages().getString("report.type.categories");
        reportTypeDevelopers = appContext.messages().getString("report.type.developers");

        reportTypeComboBox.setItems(FXCollections.observableArrayList(
                reportTypeAll, reportTypeCategories, reportTypeDevelopers
        ));
        reportTypeComboBox.getSelectionModel().selectFirst();

        reportTypeComboBox.setOnAction(e -> handleReportTypeChange());

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

        loadDevelopers();
        handleReportTypeChange();
    }

    private void loadDevelopers() {
        try {
            List<Developer> developers = appContext.softwareService().findDevelopers();
            developerComboBox.setItems(FXCollections.observableArrayList(developers));
            if (!developers.isEmpty()) {
                developerComboBox.getSelectionModel().selectFirst();
            }
        } catch (RuntimeException e) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("catalog.load.error")
            );
        }
    }

    private void handleReportTypeChange() {
        String selected = reportTypeComboBox.getValue();
        boolean isDevReport = reportTypeDevelopers.equals(selected);
        // Показ/скрытие фильтра по разработчику
        developerLabel.setVisible(isDevReport);
        developerLabel.setManaged(isDevReport);
        developerComboBox.setVisible(isDevReport);
        developerComboBox.setManaged(isDevReport);
    }

    @FXML
    private void onGenerate() {
        String selected = reportTypeComboBox.getValue();
        if (selected == null) return;

        // Очистка предыдущего отчёта
        reportTable.getColumns().clear();
        reportTable.getItems().clear();

        // Генерация отчёта по выбранному типу
        if (selected.equals(reportTypeAll)) {
            configureSoftwareColumns();
            loadAllSoftware();
        } else if (selected.equals(reportTypeCategories)) {
            configureCategoryColumns();
            loadCategoryCounts();
        } else if (selected.equals(reportTypeDevelopers)) {
            Developer selectedDev = developerComboBox.getValue();
            if (selectedDev == null) {
                DialogUtils.showError(
                        appContext.messages().getString("error.title"),
                        appContext.messages().getString("report.select.developer")
                );
                return;
            }
            configureSoftwareColumns();
            loadSoftwareByDeveloper(selectedDev.developerId());
        }
    }

    private void configureSoftwareColumns() {
        TableColumn<Object, String> titleCol = new TableColumn<>(appContext.messages().getString("software.title"));
        titleCol.setCellValueFactory(data -> new SimpleStringProperty(((Software) data.getValue()).title()));
        titleCol.setPrefWidth(150);

        TableColumn<Object, String> catCol = new TableColumn<>(appContext.messages().getString("software.category"));
        catCol.setCellValueFactory(data -> new SimpleStringProperty(TranslationUtils.getLocalizedCategory(((Software) data.getValue()).categoryName(), appContext.messages())));
        catCol.setPrefWidth(120);

        TableColumn<Object, String> devCol = new TableColumn<>(appContext.messages().getString("software.developer"));
        devCol.setCellValueFactory(data -> new SimpleStringProperty(((Software) data.getValue()).developerName() != null ? ((Software) data.getValue()).developerName() : ""));
        devCol.setPrefWidth(120);

        TableColumn<Object, String> licenseCol = new TableColumn<>(appContext.messages().getString("software.license"));
        licenseCol.setCellValueFactory(data -> new SimpleStringProperty(
                ((Software) data.getValue()).free()
                        ? appContext.messages().getString("license.free")
                        : appContext.messages().getString("license.paid")
        ));
        licenseCol.setPrefWidth(100);

        TableColumn<Object, String> ratingCol = new TableColumn<>(appContext.messages().getString("software.rating"));
        ratingCol.setCellValueFactory(data -> new SimpleStringProperty(
                ((Software) data.getValue()).averageRating() != null ? ((Software) data.getValue()).averageRating().toString() : ""
        ));
        ratingCol.setPrefWidth(80);

        TableColumn<Object, String> webCol = new TableColumn<>(appContext.messages().getString("software.website"));
        webCol.setCellValueFactory(data -> new SimpleStringProperty(((Software) data.getValue()).website() != null ? ((Software) data.getValue()).website() : ""));
        webCol.setPrefWidth(150);

        reportTable.getColumns().addAll(List.of(titleCol, catCol, devCol, licenseCol, ratingCol, webCol));
    }

    private void configureCategoryColumns() {
        TableColumn<Object, String> nameCol = new TableColumn<>(appContext.messages().getString("software.category"));
        nameCol.setCellValueFactory(data -> new SimpleStringProperty(TranslationUtils.getLocalizedCategory(((CategoryCount) data.getValue()).categoryName(), appContext.messages())));
        nameCol.setPrefWidth(250);

        TableColumn<Object, String> countCol = new TableColumn<>(appContext.messages().getString("report.category.count"));
        countCol.setCellValueFactory(data -> new SimpleStringProperty(String.valueOf(((CategoryCount) data.getValue()).count())));
        countCol.setPrefWidth(150);

        reportTable.getColumns().addAll(List.of(nameCol, countCol));
    }

    private void loadAllSoftware() {
        try {
            List<Software> list = appContext.softwareService().search(SoftwareSearchCriteria.empty());
            reportTable.getItems().addAll(list);
        } catch (RuntimeException e) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("catalog.load.error")
            );
        }
    }

    private void loadCategoryCounts() {
        try {
            List<CategoryCount> list = appContext.softwareService().getCategoryCounts();
            reportTable.getItems().addAll(list);
        } catch (RuntimeException e) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("catalog.load.error")
            );
        }
    }

    private void loadSoftwareByDeveloper(long developerId) {
        try {
            List<Software> list = appContext.softwareService().search(
                    new SoftwareSearchCriteria(null, null, developerId, null)
            );
            reportTable.getItems().addAll(list);
        } catch (RuntimeException e) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("catalog.load.error")
            );
        }
    }

    @FXML
    private void onExportCsv() {
        if (reportTable.getItems().isEmpty()) {
            return;
        }

        FileChooser fileChooser = new FileChooser();
        fileChooser.setTitle(appContext.messages().getString("report.save.title"));
        fileChooser.getExtensionFilters().add(
                new FileChooser.ExtensionFilter(appContext.messages().getString("report.file.csv"), "*.csv")
        );
        Stage stage = (Stage) reportTable.getScene().getWindow();
        File file = fileChooser.showSaveDialog(stage);

        if (file == null) {
            return;
        }

        try (var writer = new OutputStreamWriter(new FileOutputStream(file), StandardCharsets.UTF_8)) {
            // BOM для корректного открытия в Excel
            writer.write('\ufeff');

            // Запись заголовков колонок
            List<String> headers = new ArrayList<>();
            for (TableColumn<Object, ?> col : reportTable.getColumns()) {
                headers.add(escapeCsv(col.getText()));
            }
            writer.write(String.join(";", headers) + "\n");

            // Запись строк данных
            for (Object item : reportTable.getItems()) {
                List<String> row = new ArrayList<>();
                for (TableColumn<Object, ?> col : reportTable.getColumns()) {
                    var cellValue = col.getCellData(item);
                    row.add(escapeCsv(cellValue == null ? "" : cellValue.toString()));
                }
                writer.write(String.join(";", row) + "\n");
            }

            DialogUtils.showInfo(
                    appContext.messages().getString("app.title"),
                    appContext.messages().getString("report.export.success")
            );
        } catch (Exception e) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("report.export.error") + ": " + e.getMessage()
            );
        }
    }

    private String escapeCsv(String val) {
        if (val == null) return "";
        // Экранирование двойных кавычек
        String escaped = val.replace("\"", "\"\"");
        // Обёртывание в кавычки при наличии спецсимволов
        if (escaped.contains(";") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r")) {
            return "\"" + escaped + "\"";
        }
        return escaped;
    }

    @FXML
    private void onClose() {
        Stage stage = (Stage) reportTable.getScene().getWindow();
        stage.close();
    }
}
