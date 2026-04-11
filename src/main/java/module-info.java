module com.coursework.softwareanalogues {
    requires java.sql;
    requires javafx.controls;
    requires javafx.fxml;
    requires org.slf4j;
    requires org.postgresql.jdbc;

    opens com.coursework.softwareanalogues.controller to javafx.fxml;
    opens com.coursework.softwareanalogues.model to javafx.base;

    exports com.coursework.softwareanalogues;
    exports com.coursework.softwareanalogues.model;
    exports com.coursework.softwareanalogues.service;
    exports com.coursework.softwareanalogues.dao;
}
