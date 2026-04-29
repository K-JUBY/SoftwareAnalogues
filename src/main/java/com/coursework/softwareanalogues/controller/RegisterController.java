package com.coursework.softwareanalogues.controller;

import com.coursework.softwareanalogues.config.AppContext;
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

public final class RegisterController {
    private static final Logger logger = LoggerFactory.getLogger(RegisterController.class);

    private final AppContext appContext;
    private final FxmlLoader fxmlLoader;

    @FXML
    private TextField usernameField;
    @FXML
    private PasswordField passwordField;
    @FXML
    private PasswordField confirmPasswordField;
    @FXML
    private Button registerButton;
    @FXML
    private ComboBox<String> languageComboBox;

    public RegisterController(AppContext appContext, FxmlLoader fxmlLoader) {
        this.appContext = appContext;
        this.fxmlLoader = fxmlLoader;
    }

    @FXML
    private void initialize() {
        // Блокировка кнопки регистрации при незаполненных полях
        registerButton.disableProperty().bind(
                usernameField.textProperty().isEmpty()
                        .or(passwordField.textProperty().isEmpty())
                        .or(confirmPasswordField.textProperty().isEmpty())
        );
        configureLanguageSelector();
    }

    private void configureLanguageSelector() {
        languageComboBox.setItems(FXCollections.observableArrayList("Русский", "English", "Deutsch"));
        
        String currentLocale = Locale.getDefault().getLanguage();
        if ("en".equals(currentLocale)) {
            languageComboBox.getSelectionModel().select("English");
        } else if ("de".equals(currentLocale)) {
            languageComboBox.getSelectionModel().select("Deutsch");
        } else {
            languageComboBox.getSelectionModel().select("Русский");
        }
        
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
            Locale newLocale = Locale.forLanguageTag(localeCode);
            appContext.setLocale(newLocale);
            
            Stage stage = (Stage) registerButton.getScene().getWindow();
            stage.setScene(new Scene(fxmlLoader.load("register-view.fxml"), 420, 350));
        } catch (Exception e) {
            logger.error("Failed to switch language in register screen", e);
        }
    }

    @FXML
    private void onRegister() {
        String username = usernameField.getText().trim();
        String password = passwordField.getText();
        String confirmPassword = confirmPasswordField.getText();

        // Проверка совпадения паролей
        if (!password.equals(confirmPassword)) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("register.error.mismatch")
            );
            return;
        }

        // Валидация формата логина
        if (!username.matches("^[a-zA-Z0-9_]{3,30}$")) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("register.error.invalid_username")
            );
            return;
        }

        // Валидация минимальной длины пароля
        if (password.length() < 6) {
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("register.error.invalid_password")
            );
            return;
        }

        // Регистрация через AuthService
        try {
            appContext.authService().register(username, password);
            DialogUtils.showInfo(
                    appContext.messages().getString("app.title"),
                    appContext.messages().getString("register.success")
            );
            navigateToLogin();
        } catch (AppException e) {
            logger.error("Registration failed", e);
            DialogUtils.showError(
                    appContext.messages().getString("error.title"),
                    appContext.messages().getString("register.error") + ": " + e.getMessage()
            );
        }
    }

    @FXML
    private void onCancel() {
        navigateToLogin();
    }

    private void navigateToLogin() {
        Stage stage = (Stage) registerButton.getScene().getWindow();
        stage.setScene(new Scene(fxmlLoader.load("login-view.fxml"), 420, 320));
    }
}
