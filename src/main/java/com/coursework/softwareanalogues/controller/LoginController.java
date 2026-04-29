package com.coursework.softwareanalogues.controller;

import com.coursework.softwareanalogues.config.AppContext;
import com.coursework.softwareanalogues.exception.AuthenticationException;
import com.coursework.softwareanalogues.exception.AppException;
import com.coursework.softwareanalogues.util.DialogUtils;
import com.coursework.softwareanalogues.util.FxmlLoader;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.ComboBox;
import javafx.scene.control.PasswordField;
import javafx.scene.control.TextField;
import javafx.stage.Stage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Locale;

public final class LoginController {
    private static final Logger logger = LoggerFactory.getLogger(LoginController.class);

    private final AppContext appContext;
    private final FxmlLoader fxmlLoader;

    @FXML
    private TextField usernameField;
    @FXML
    private PasswordField passwordField;
    @FXML
    private Button loginButton;
    @FXML
    private ComboBox<String> languageComboBox;

    public LoginController(AppContext appContext, FxmlLoader fxmlLoader) {
        this.appContext = appContext;
        this.fxmlLoader = fxmlLoader;
    }

    @FXML
    private void initialize() {
        // Блокировка кнопки входа при пустых полях
        loginButton.disableProperty().bind(
                usernameField.textProperty().isEmpty().or(passwordField.textProperty().isEmpty())
        );
        configureLanguageSelector();
    }

    private void configureLanguageSelector() {
        languageComboBox.setItems(FXCollections.observableArrayList("Русский", "English", "Deutsch"));
        
        // Установка текущей локали в ComboBox
        String currentLocale = Locale.getDefault().getLanguage();
        if ("en".equals(currentLocale)) {
            languageComboBox.getSelectionModel().select("English");
        } else if ("de".equals(currentLocale)) {
            languageComboBox.getSelectionModel().select("Deutsch");
        } else {
            languageComboBox.getSelectionModel().select("Русский");
        }
        
        // Обработчик смены языка
        languageComboBox.valueProperty().addListener((observable, oldValue, newValue) -> {
            if (newValue != null) {
                String code = switch (newValue) {
                    case "English" -> "en";
                    case "Deutsch" -> "de";
                    default -> "ru";
                };
                changeLanguage(code);
            }
        });
    }

    private void changeLanguage(String localeCode) {
        try {
            // Смена локали в AppContext
            Locale newLocale = Locale.forLanguageTag(localeCode);
            appContext.setLocale(newLocale);
            
            // Перезагрузка окна с новым языком
            Stage stage = (Stage) loginButton.getScene().getWindow();
            stage.setScene(new Scene(fxmlLoader.load("login-view.fxml"), 420, 320));
        } catch (Exception e) {
            logger.error("Failed to switch language in login screen", e);
        }
    }

    @FXML
    private void onLogin() {
        try {
            // Аутентификация через AuthService
            appContext.authService().login(usernameField.getText(), passwordField.getText());
            // Переход в главное окно при успехе
            Stage stage = (Stage) loginButton.getScene().getWindow();
            stage.setScene(new Scene(fxmlLoader.load("main-view.fxml"), 1024, 700));
            stage.setMinWidth(1000);
            stage.setMinHeight(660);
        } catch (AuthenticationException e) {
            logger.warn("Login failed for '{}': {}", usernameField.getText(), e.getMessage());
            DialogUtils.showError(
                    appContext.messages().getString("login.error.title"),
                    appContext.messages().getString("login.error.message")
            );
        } catch (AppException e) {
            logger.error("Login operation failed", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("login.system.error")
            );
        }
    }

    @FXML
    private void onRegisterLinkClick() {
        try {
            Stage stage = (Stage) loginButton.getScene().getWindow();
            stage.setScene(new Scene(fxmlLoader.load("register-view.fxml"), 420, 350));
        } catch (AppException e) {
            logger.error("Failed to load registration screen", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("register.error")
            );
        }
    }
}
