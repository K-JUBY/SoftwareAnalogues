package com.coursework.softwareanalogues.exception;

public final class DatabaseException extends AppException {
    public DatabaseException(String message) {
        super(message);
    }

    public DatabaseException(String message, Throwable cause) {
        super(message, cause);
    }
}
