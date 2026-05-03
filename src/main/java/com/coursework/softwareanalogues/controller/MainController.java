package com.coursework.softwareanalogues.controller;

import com.coursework.softwareanalogues.config.AppContext;
import com.coursework.softwareanalogues.model.Category;
import com.coursework.softwareanalogues.model.Software;
import com.coursework.softwareanalogues.model.SoftwareFormMode;
import com.coursework.softwareanalogues.model.SoftwareSearchCriteria;
import com.coursework.softwareanalogues.util.DialogUtils;
import com.coursework.softwareanalogues.util.TranslationUtils;
import com.coursework.softwareanalogues.util.FxmlLoader;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Label;
import javafx.scene.control.SelectionMode;
import javafx.scene.control.TableColumn;
import javafx.scene.control.TableView;
import javafx.scene.control.TextField;
import javafx.scene.Scene;
import javafx.stage.Modality;
import javafx.stage.Stage;
import javafx.util.StringConverter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Locale;

public final class MainController {
    private static final Logger logger = LoggerFactory.getLogger(MainController.class);

    private final AppContext appContext;
    private final FxmlLoader fxmlLoader;

    @FXML
    private Label userLabel;
    @FXML
    private ComboBox<String> languageComboBox;
    @FXML
    private TextField queryField;
    @FXML
    private ComboBox<Category> categoryComboBox;
    @FXML
    private ComboBox<String> licenseComboBox;
    @FXML
    private TableView<Software> softwareTable;
    @FXML
    private TableColumn<Software, String> titleColumn;
    @FXML
    private TableColumn<Software, String> categoryColumn;
    @FXML
    private TableColumn<Software, String> developerColumn;
    @FXML
    private TableColumn<Software, String> licenseColumn;
    @FXML
    private TableColumn<Software, String> ratingColumn;

    public MainController(AppContext appContext, FxmlLoader fxmlLoader) {
        this.appContext = appContext;
        this.fxmlLoader = fxmlLoader;
    }

    @FXML
    private void initialize() {
        // Установка имени текущего пользователя
        userLabel.setText(appContext.authService().currentUser().username());
        // Настройка компонентов интерфейса
        configureTable();
        configureFilters();
        configureLanguageSelector();
        loadCategories();
        // Первоначальная загрузка данных
        onSearch();
    }

    // Поиск ПО по заданным критериям
    @FXML
    private void onSearch() {
        try {
            Category selectedCategory = categoryComboBox.getValue();
            // Определение типа лицензии из выбранного индекса
            Boolean free = switch (licenseComboBox.getSelectionModel().getSelectedIndex()) {
                case 1 -> Boolean.TRUE;
                case 2 -> Boolean.FALSE;
                default -> null;
            };
            // Формирование критериев поиска
            SoftwareSearchCriteria criteria = new SoftwareSearchCriteria(
                    queryField.getText(),
                    selectedCategory == null || selectedCategory.categoryId() == 0 ? null : selectedCategory.categoryId(),
                    null,
                    free
            );
            // Обновление таблицы результатами поиска
            softwareTable.setItems(FXCollections.observableArrayList(appContext.softwareService().search(criteria)));
            logger.info("Software search completed");
        } catch (RuntimeException e) {
            logger.error("Software search failed", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("catalog.load.error")
            );
        }
    }

    // Открытие формы добавления нового ПО
    @FXML
    private void onAddSoftware() {
        openSoftwareForm(SoftwareFormMode.CREATE, null);
    }

    // Открытие формы редактирования выбранного ПО
    @FXML
    private void onEditSoftware() {
        Software selected = softwareTable.getSelectionModel().getSelectedItem();
        // Проверка выбора элемента в таблице
        if (selected == null) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("catalog.select.required")
            );
            return;
        }
        openSoftwareForm(SoftwareFormMode.EDIT, selected);
    }

    // Удаление выбранного ПО
    @FXML
    private void onDeleteSoftware() {
        Software selected = softwareTable.getSelectionModel().getSelectedItem();
        // Проверка выбора элемента в таблице
        if (selected == null) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("catalog.select.required")
            );
            return;
        }

        // Запрос подтверждения удаления
        boolean confirmed = DialogUtils.confirm(
                appContext.messages().getString("software.delete.confirm.title"),
                appContext.messages().getString("software.delete.confirm.message")
        );
        if (!confirmed) {
            return;
        }

        try {
            appContext.softwareService().deleteById(selected.softwareId());
            // Обновление списка после удаления
            onSearch();
        } catch (RuntimeException e) {
            logger.error("Software deletion failed", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("software.delete.error")
            );
        }
    }

    // Открытие окна детальной информации о ПО
    @FXML
    private void onOpenDetails() {
        Software selected = softwareTable.getSelectionModel().getSelectedItem();
        // Проверка выбора элемента в таблице
        if (selected == null) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("catalog.select.required")
            );
            return;
        }

        try {
            // Создание модального окна
            Stage dialog = new Stage();
            dialog.initModality(Modality.APPLICATION_MODAL);
            dialog.setTitle(selected.title());
            dialog.setScene(new Scene(fxmlLoader.loadSoftwareDetails(selected, this::onSearch), 850, 780));
            dialog.showAndWait();
        } catch (RuntimeException e) {
            logger.error("Failed to open software details", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("software.details.open.error")
            );
        }
    }

    // Открытие окна управления коллекциями
    @FXML
    private void onOpenCollections() {
        try {
            Stage dialog = new Stage();
            dialog.initModality(Modality.APPLICATION_MODAL);
            dialog.setTitle(appContext.messages().getString("collections.title"));
            dialog.setScene(new Scene(fxmlLoader.loadCollections(), 880, 600));
            dialog.showAndWait();
        } catch (RuntimeException e) {
            logger.error("Failed to open collections", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("collections.open.error")
            );
        }
    }

    // Открытие окна сравнения выбранных программ
    @FXML
    private void onCompare() {
        var selected = softwareTable.getSelectionModel().getSelectedItems();
        // Проверка выбора минимум двух элементов
        if (selected == null || selected.size() < 2) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("compare.select.required")
            );
            return;
        }

        try {
            Stage dialog = new Stage();
            dialog.initModality(Modality.APPLICATION_MODAL);
            dialog.setTitle(appContext.messages().getString("software.compare.title"));
            dialog.setScene(new Scene(fxmlLoader.loadComparison(new java.util.ArrayList<>(selected)), 950, 600));
            dialog.showAndWait();
        } catch (RuntimeException e) {
            logger.error("Failed to open comparison window", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("compare.open.error")
            );
        }
    }

    // Открытие окна отчетов и статистики
    @FXML
    private void onOpenReports() {
        try {
            Stage dialog = new Stage();
            dialog.initModality(Modality.APPLICATION_MODAL);
            dialog.setTitle(appContext.messages().getString("reports.title"));
            dialog.setScene(new Scene(fxmlLoader.loadReports(), 900, 650));
            dialog.showAndWait();
        } catch (RuntimeException e) {
            logger.error("Failed to open reports window", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("reports.open.error")
            );
        }
    }

    // Выход из системы и возврат к экрану входа
    @FXML
    private void onLogout() {
        try {
            appContext.authService().logout();
            // Переключение на экран входа
            Stage stage = (Stage) languageComboBox.getScene().getWindow();
            stage.setScene(new Scene(fxmlLoader.load("login-view.fxml"), 420, 320));
            stage.setMinWidth(420);
            stage.setMinHeight(320);
            logger.info("Successfully logged out and redirected to login screen");
        } catch (Exception e) {
            logger.error("Failed to log out", e);
        }
    }

    // Открытие формы создания/редактирования ПО
    private void openSoftwareForm(SoftwareFormMode mode, Software software) {
        try {
            Stage dialog = new Stage();
            dialog.initModality(Modality.APPLICATION_MODAL);
            // Установка заголовка в зависимости от режима
            dialog.setTitle(appContext.messages().getString(
                    mode == SoftwareFormMode.CREATE ? "software.form.add.title" : "software.form.edit.title"
            ));
            // Callback для закрытия формы и обновления списка
            dialog.setScene(new Scene(fxmlLoader.loadSoftwareForm(mode, software, () -> {
                dialog.close();
                onSearch();
            }), 560, 720));
            dialog.showAndWait();
        } catch (RuntimeException e) {
            logger.error("Failed to open software form", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("software.form.open.error")
            );
        }
    }

    // Настройка таблицы с ПО и её колонок
    private void configureTable() {
        softwareTable.setColumnResizePolicy(TableView.CONSTRAINED_RESIZE_POLICY_FLEX_LAST_COLUMN);
        // Привязка данных к колонкам таблицы
        titleColumn.setCellValueFactory(data -> new SimpleStringProperty(data.getValue().title()));
        categoryColumn.setCellValueFactory(data -> new SimpleStringProperty(TranslationUtils.getLocalizedCategory(data.getValue().categoryName(), appContext.messages())));
        developerColumn.setCellValueFactory(data -> new SimpleStringProperty(nullToEmpty(data.getValue().developerName())));
        licenseColumn.setCellValueFactory(data -> new SimpleStringProperty(
                data.getValue().free()
                        ? appContext.messages().getString("license.free")
                        : appContext.messages().getString("license.paid")
        ));
        ratingColumn.setCellValueFactory(data -> new SimpleStringProperty(
                data.getValue().averageRating() == null ? "" : data.getValue().averageRating().toString()
        ));
        // Включение множественного выбора
        softwareTable.getSelectionModel().setSelectionMode(SelectionMode.MULTIPLE);

        // Настройка обработчиков строк таблицы
        softwareTable.setRowFactory(tv -> {
            var row = new javafx.scene.control.TableRow<Software>();
            
            // Обработчик двойного клика для открытия деталей
            row.setOnMouseClicked(event -> {
                if (event.getClickCount() == 2 && (!row.isEmpty())) {
                    onOpenDetails();
                }
            });
            
            // Создание контекстного меню
            var contextMenu = new javafx.scene.control.ContextMenu();
            
            var detailsItem = new javafx.scene.control.MenuItem(appContext.messages().getString("menu.details"));
            detailsItem.setOnAction(event -> onOpenDetails());
            
            var compareItem = new javafx.scene.control.MenuItem(appContext.messages().getString("menu.compare"));
            compareItem.setOnAction(event -> onCompare());
            
            var addToCollectionMenu = new javafx.scene.control.Menu(appContext.messages().getString("menu.add_to_collection"));
            
            // Динамическая загрузка коллекций при открытии меню
            contextMenu.setOnShowing(event -> {
                addToCollectionMenu.getItems().clear();
                try {
                    var collections = appContext.softwareService().findCollections();
                    if (collections.isEmpty()) {
                        var emptyItem = new javafx.scene.control.MenuItem(appContext.messages().getString("menu.no_collections"));
                        emptyItem.setDisable(true);
                        addToCollectionMenu.getItems().add(emptyItem);
                    } else {
                        // Создание пункта меню для каждой коллекции
                        for (var collection : collections) {
                            var item = new javafx.scene.control.MenuItem(collection.title());
                            item.setOnAction(e -> {
                                var selectedSoftware = row.getItem();
                                if (selectedSoftware != null) {
                                    try {
                                        appContext.softwareService().addCollectionItem(collection.collectionId(), selectedSoftware.softwareId(), null, null);
                                        DialogUtils.showInfo(
                                            appContext.messages().getString("app.title"),
                                            appContext.messages().getString("collection.item.added.success")
                                        );
                                    } catch (Exception ex) {
                                        logger.error("Failed to add software to collection", ex);
                                        DialogUtils.showError(
                                            appContext.messages().getString("error.title"),
                                            appContext.messages().getString("collection.item.added.error")
                                        );
                                    }
                                }
                            });
                            addToCollectionMenu.getItems().add(item);
                        }
                    }
                } catch (Exception ex) {
                    logger.error("Failed to load collections for context menu", ex);
                }
            });
            
            contextMenu.getItems().addAll(detailsItem, compareItem, addToCollectionMenu);
            
            // Привязка контекстного меню только к заполненным строкам
            row.contextMenuProperty().bind(
                javafx.beans.binding.Bindings.when(row.emptyProperty())
                    .then((javafx.scene.control.ContextMenu) null)
                    .otherwise(contextMenu)
            );
            
            return row;
        });
    }

    // Настройка фильтров поиска
    private void configureFilters() {
        // Заполнение выпадающего списка типов лицензий
        licenseComboBox.setItems(FXCollections.observableArrayList(
                appContext.messages().getString("filter.license.all"),
                appContext.messages().getString("license.free"),
                appContext.messages().getString("license.paid")
        ));
        licenseComboBox.getSelectionModel().selectFirst();

        // Настройка конвертера для локализации названий категорий
        categoryComboBox.setConverter(new StringConverter<>() {
            @Override
            public String toString(Category category) {
                if (category == null) return "";
                if (category.categoryId() == 0) {
                    return category.name();
                }
                return TranslationUtils.getLocalizedCategory(category.name(), appContext.messages());
            }

            @Override
            public Category fromString(String string) {
                return null;
            }
        });

        // Автоматический поиск при изменении фильтров
        queryField.textProperty().addListener((observable, oldValue, newValue) -> onSearch());
        categoryComboBox.valueProperty().addListener((observable, oldValue, newValue) -> onSearch());
        licenseComboBox.valueProperty().addListener((observable, oldValue, newValue) -> onSearch());
    }

    // Настройка переключателя языков интерфейса
    private void configureLanguageSelector() {
        languageComboBox.setItems(FXCollections.observableArrayList("Русский", "English", "Deutsch"));
        
        // Установка текущего языка из Locale.getDefault()
        String currentLocale = Locale.getDefault().getLanguage();
        if (currentLocale.equals("ru")) {
            languageComboBox.getSelectionModel().select("Русский");
        } else if (currentLocale.equals("de")) {
            languageComboBox.getSelectionModel().select("Deutsch");
        } else {
            languageComboBox.getSelectionModel().select("English");
        }
        
        // Обработчик смены языка
        languageComboBox.setOnAction(e -> {
            String selected = languageComboBox.getValue();
            if (selected == null) return;
            
            String currentLang = Locale.getDefault().getLanguage();
            String newLang = "en";
            if (selected.equals("Русский")) {
                newLang = "ru";
            } else if (selected.equals("Deutsch")) {
                newLang = "de";
            }
            
            // Пропуск повторного переключения на тот же язык
            if (currentLang.equals(newLang)) return;
            
            switchLocale(newLang);
        });
    }

    // Переключение языка интерфейса с перезагрузкой окна
    private void switchLocale(String localeCode) {
        try {
            Stage stage = (Stage) languageComboBox.getScene().getWindow();
            double currentWidth = stage.getScene().getWidth();
            double currentHeight = stage.getScene().getHeight();
            
            // Обновление локали в AppContext
            Locale newLocale = Locale.forLanguageTag(localeCode);
            appContext.setLocale(newLocale);
            java.util.ResourceBundle newBundle = appContext.messages();
            
            // Перезагрузка главного окна с новым ResourceBundle
            javafx.fxml.FXMLLoader loader = new javafx.fxml.FXMLLoader(
                getClass().getResource("/fxml/main-view.fxml"),
                newBundle
            );
            
            // Настройка фабрики контроллеров
            loader.setControllerFactory(controllerClass -> {
                if (controllerClass == MainController.class) {
                    return new MainController(appContext, fxmlLoader);
                }
                throw new RuntimeException("Unexpected controller: " + controllerClass);
            });
            
            // Применение новой сцены с сохранением размеров окна
            Scene newScene = new Scene(loader.load(), currentWidth, currentHeight);
            stage.setScene(newScene);
            stage.setTitle(newBundle.getString("app.title"));
            
            logger.info("Language switched to: {}", localeCode);
        } catch (Exception ex) {
            logger.error("Failed to switch language", ex);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("error.switch_language") + ": " + ex.getMessage()
            );
        }
    }

    // Загрузка списка категорий в фильтр
    private void loadCategories() {
        var categories = FXCollections.observableArrayList(appContext.softwareService().findCategories());
        // Добавление варианта "Все категории"
        categories.add(0, new Category(0, appContext.messages().getString("filter.category.all"), null));
        categoryComboBox.setItems(categories);
        categoryComboBox.getSelectionModel().selectFirst();
    }

    // Преобразование null в пустую строку
    private String nullToEmpty(String value) {
        return value == null ? "" : value;
    }
}
