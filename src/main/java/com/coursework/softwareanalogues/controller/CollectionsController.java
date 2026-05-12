package com.coursework.softwareanalogues.controller;

import com.coursework.softwareanalogues.config.AppContext;
import com.coursework.softwareanalogues.model.CollectionItem;
import com.coursework.softwareanalogues.model.UserCollection;
import com.coursework.softwareanalogues.util.DialogUtils;
import com.coursework.softwareanalogues.util.TranslationUtils;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.TableColumn;
import javafx.scene.control.TableView;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;

public final class CollectionsController {
    private final AppContext appContext;

    @FXML
    private TableView<UserCollection> collectionsTable;
    @FXML
    private TableColumn<UserCollection, String> collectionTitleColumn;
    @FXML
    private TableColumn<UserCollection, String> collectionCountColumn;
    @FXML
    private TableView<CollectionItem> itemsTable;
    @FXML
    private TableColumn<CollectionItem, String> itemTitleColumn;
    @FXML
    private TableColumn<CollectionItem, String> itemCategoryColumn;
    @FXML
    private TableColumn<CollectionItem, String> itemNoteColumn;
    @FXML
    private TextField titleField;
    @FXML
    private TextArea descriptionArea;

    public CollectionsController(AppContext appContext) {
        this.appContext = appContext;
    }

    @FXML
    private void initialize() {
        // Настройка колонок таблицы коллекций
        collectionTitleColumn.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().title()));
        collectionCountColumn.setCellValueFactory(data -> new SimpleStringProperty(Long.toString(data.getValue().itemCount())));
        // Настройка колонок таблицы элементов
        itemTitleColumn.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().title()));
        itemCategoryColumn.setCellValueFactory(data -> new SimpleStringProperty(TranslationUtils.getLocalizedCategory(data.getValue().categoryName(), appContext.messages())));
        itemNoteColumn.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().note()));
        // Автозагрузка элементов при выборе коллекции
        collectionsTable.getSelectionModel().selectedItemProperty().addListener((observable, oldValue, newValue) -> loadItems(newValue));
        loadCollections();
    }

    @FXML
    private void onCreateCollection() {
        // Создание новой коллекции
        try {
            appContext.softwareService().createCollection(titleField.getText(), descriptionArea.getText());
            titleField.clear();
            descriptionArea.clear();
            loadCollections();
        } catch (RuntimeException e) {
            DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("collection.create.error"));
        }
    }

    @FXML
    private void onDeleteCollection() {
        UserCollection selected = collectionsTable.getSelectionModel().getSelectedItem();
        if (selected == null) {
            DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("collection.select.required"));
            return;
        }
        // Подтверждение удаления
        if (!DialogUtils.confirm(appContext.messages().getString("collection.delete.confirm.title"), appContext.messages().getString("collection.delete.confirm.message"))) {
            return;
        }
        // Удаление коллекции с каскадным удалением элементов
        appContext.softwareService().deleteCollection(selected.collectionId());
        loadCollections();
        itemsTable.getItems().clear();
    }

    @FXML
    private void onRemoveItem() {
        UserCollection collection = collectionsTable.getSelectionModel().getSelectedItem();
        CollectionItem item = itemsTable.getSelectionModel().getSelectedItem();
        if (collection == null || item == null) {
            DialogUtils.showError(appContext.messages().getString("error.title"), appContext.messages().getString("collection.item.select.required"));
            return;
        }
        // Удаление программы из коллекции
        appContext.softwareService().removeCollectionItem(collection.collectionId(), item.softwareId());
        loadItems(collection);
        loadCollections();
    }

    private void loadCollections() {
        collectionsTable.setItems(FXCollections.observableArrayList(appContext.softwareService().findCollections()));
    }

    private void loadItems(UserCollection collection) {
        // Очистка при отсутствии выбранной коллекции
        if (collection == null) {
            itemsTable.getItems().clear();
            return;
        }
        // Загрузка элементов выбранной коллекции
        itemsTable.setItems(FXCollections.observableArrayList(appContext.softwareService().findCollectionItems(collection.collectionId())));
    }
}
