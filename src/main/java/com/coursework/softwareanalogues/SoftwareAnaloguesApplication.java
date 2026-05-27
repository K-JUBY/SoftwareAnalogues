package com.coursework.softwareanalogues;

import com.coursework.softwareanalogues.config.AppContext;
import com.coursework.softwareanalogues.util.FxmlLoader;
import javafx.application.Application;
import javafx.scene.Scene;
import javafx.stage.Stage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.Locale;

public class SoftwareAnaloguesApplication extends Application {
    private static final Logger logger = LoggerFactory.getLogger(SoftwareAnaloguesApplication.class);

    private AppContext appContext;
    private Stage primaryStage;

    @Override
    public void start(Stage stage) throws IOException {
        this.primaryStage = stage;
        appContext = AppContext.create();
        var loader = new FxmlLoader(appContext);
        Scene scene = new Scene(loader.load("login-view.fxml"), 420, 320);

        stage.setTitle(appContext.messages().getString("app.title"));
        stage.setScene(scene);
        stage.setMinWidth(420);
        stage.setMinHeight(320);
        stage.show();
        logger.info("Application started");
    }

    @Override
    public void stop() {
        if (appContext != null) {
            appContext.close();
        }
        logger.info("Application stopped");
    }

    public static void main(String[] args) {
        launch(args);
    }
}
