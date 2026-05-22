package com.coursework.softwareanalogues.util;

import com.coursework.softwareanalogues.config.AppContext;
import com.coursework.softwareanalogues.controller.CollectionsController;
import com.coursework.softwareanalogues.controller.LoginController;
import com.coursework.softwareanalogues.controller.MainController;
import com.coursework.softwareanalogues.controller.SoftwareDetailsController;
import com.coursework.softwareanalogues.controller.SoftwareFormController;
import com.coursework.softwareanalogues.controller.ComparisonController;
import com.coursework.softwareanalogues.controller.ReportsController;
import com.coursework.softwareanalogues.controller.RegisterController;
import com.coursework.softwareanalogues.exception.AppException;
import com.coursework.softwareanalogues.model.Software;
import com.coursework.softwareanalogues.model.SoftwareFormMode;
import javafx.fxml.FXMLLoader;
import javafx.scene.Parent;

import java.io.IOException;
import java.util.List;

public final class FxmlLoader {
    private final AppContext appContext;

    public FxmlLoader(AppContext appContext) {
        this.appContext = appContext;
    }

    public Parent load(String fileName) {
        // Загрузка FXML с текущим ResourceBundle
        FXMLLoader loader = new FXMLLoader(
                FxmlLoader.class.getResource("/fxml/" + fileName),
                appContext.messages()
        );
        loader.setControllerFactory(this::createController);
        try {
            return loader.load();
        } catch (IOException e) {
            throw new AppException("Failed to load FXML: " + fileName, e);
        }
    }

    public Parent loadSoftwareForm(SoftwareFormMode mode, Software software, Runnable onSaved) {
        FXMLLoader loader = new FXMLLoader(
                FxmlLoader.class.getResource("/fxml/software-form-view.fxml"),
                appContext.messages()
        );
        loader.setControllerFactory(controllerClass -> {
            if (controllerClass == SoftwareFormController.class) {
                return new SoftwareFormController(appContext, mode, software, onSaved);
            }
            return createController(controllerClass);
        });
        try {
            return loader.load();
        } catch (IOException e) {
            throw new AppException("Failed to load software form", e);
        }
    }

    public Parent loadSoftwareDetails(Software software, Runnable onChanged) {
        FXMLLoader loader = new FXMLLoader(
                FxmlLoader.class.getResource("/fxml/software-details-view.fxml"),
                appContext.messages()
        );
        loader.setControllerFactory(controllerClass -> {
            if (controllerClass == SoftwareDetailsController.class) {
                return new SoftwareDetailsController(appContext, software, onChanged);
            }
            return createController(controllerClass);
        });
        try {
            return loader.load();
        } catch (IOException e) {
            throw new AppException("Failed to load software details", e);
        }
    }

    public Parent loadCollections() {
        FXMLLoader loader = new FXMLLoader(
                FxmlLoader.class.getResource("/fxml/collections-view.fxml"),
                appContext.messages()
        );
        loader.setControllerFactory(controllerClass -> {
            if (controllerClass == CollectionsController.class) {
                return new CollectionsController(appContext);
            }
            return createController(controllerClass);
        });
        try {
            return loader.load();
        } catch (IOException e) {
            throw new AppException("Failed to load collections", e);
        }
    }

    public Parent loadComparison(List<Software> softwareList) {
        FXMLLoader loader = new FXMLLoader(
                FxmlLoader.class.getResource("/fxml/comparison-view.fxml"),
                appContext.messages()
        );
        loader.setControllerFactory(controllerClass -> {
            if (controllerClass == ComparisonController.class) {
                return new ComparisonController(appContext, softwareList);
            }
            return createController(controllerClass);
        });
        try {
            return loader.load();
        } catch (IOException e) {
            throw new AppException("Failed to load comparison", e);
        }
    }

    public Parent loadReports() {
        FXMLLoader loader = new FXMLLoader(
                FxmlLoader.class.getResource("/fxml/reports-view.fxml"),
                appContext.messages()
        );
        loader.setControllerFactory(controllerClass -> {
            if (controllerClass == ReportsController.class) {
                return new ReportsController(appContext);
            }
            return createController(controllerClass);
        });
        try {
            return loader.load();
        } catch (IOException e) {
            throw new AppException("Failed to load reports", e);
        }
    }

    private Object createController(Class<?> controllerClass) {
        // Фабрика контроллеров с внедрением зависимостей
        if (controllerClass == LoginController.class) {
            return new LoginController(appContext, this);
        }
        if (controllerClass == RegisterController.class) {
            return new RegisterController(appContext, this);
        }
        if (controllerClass == MainController.class) {
            return new MainController(appContext, this);
        }
        throw new AppException("Unsupported controller: " + controllerClass.getName());
    }
}
