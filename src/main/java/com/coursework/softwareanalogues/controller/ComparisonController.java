package com.coursework.softwareanalogues.controller;

import com.coursework.softwareanalogues.config.AppContext;
import com.coursework.softwareanalogues.model.Software;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.fxml.FXML;
import javafx.scene.control.TableColumn;
import javafx.scene.control.TableView;
import javafx.stage.Stage;

import java.util.ArrayList;
import java.util.List;

public final class ComparisonController {
    private final AppContext appContext;
    private final List<Software> softwareList;

    @FXML
    private TableView<List<String>> comparisonTable;

    public ComparisonController(AppContext appContext, List<Software> softwareList) {
        this.appContext = appContext;
        this.softwareList = softwareList;
    }

    @FXML
    private void initialize() {
        configureColumns();
        populateData();
    }

    @FXML
    private void onClose() {
        Stage stage = (Stage) comparisonTable.getScene().getWindow();
        stage.close();
    }

    private void configureColumns() {
        // Первая колонка с названием характеристики
        TableColumn<List<String>, String> charCol = new TableColumn<>(appContext.messages().getString("compare.characteristic"));
        charCol.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().get(0)));
        charCol.setPrefWidth(180);
        comparisonTable.getColumns().add(charCol);

        // Динамическое создание колонок для каждой программы
        for (int i = 0; i < softwareList.size(); i++) {
            final int index = i + 1;
            Software s = softwareList.get(i);
            TableColumn<List<String>, String> softCol = new TableColumn<>(s.title());
            softCol.setCellValueFactory(data -> new SimpleStringProperty(
                    index < data.getValue().size() ? data.getValue().get(index) : ""
            ));
            softCol.setPrefWidth(180);
            comparisonTable.getColumns().add(softCol);
        }
    }

    private void populateData() {
        ObservableList<List<String>> rows = FXCollections.observableArrayList();

        // Строка с разработчиками
        rows.add(createRow(appContext.messages().getString("software.developer"), 
                softwareList.stream().map(s -> s.developerName() == null ? "" : s.developerName()).toList()));

        // Строка с описаниями
        rows.add(createRow(appContext.messages().getString("software.description"), 
                softwareList.stream().map(s -> s.description() == null ? "" : s.description()).toList()));

        // Строка с системными требованиями
        rows.add(createRow(appContext.messages().getString("software.requirements"), 
                softwareList.stream().map(s -> s.systemRequirements() == null ? "" : s.systemRequirements()).toList()));

        // Строка с размером
        rows.add(createRow(appContext.messages().getString("software.size"), 
                softwareList.stream().map(s -> s.sizeMb() == null ? "" : s.sizeMb().toString()).toList()));

        // Строка с веб-сайтами
        rows.add(createRow(appContext.messages().getString("software.website"), 
                softwareList.stream().map(s -> s.website() == null ? "" : s.website()).toList()));

        // Строка с рейтингами
        rows.add(createRow(appContext.messages().getString("software.rating"), 
                softwareList.stream().map(s -> s.averageRating() == null ? "" : s.averageRating().toString()).toList()));

        comparisonTable.setItems(rows);
    }

    private List<String> createRow(String title, List<String> values) {
        List<String> row = new ArrayList<>();
        row.add(title);
        row.addAll(values);
        return row;
    }
}
